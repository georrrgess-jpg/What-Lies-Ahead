class_name AlphaBossBehaviour
extends EnemyBehaviour
## A finale alpha: a named, oversized version of a world's signature enemy
## (data/enemies/**/alpha_*.tres). On top of that enemy's own behaviour it has
## readable patterns of its own:
##
##   - Phases: at each health threshold it stops and roars (shots do little
##     while it roars), shoves the player back, speeds up, its moves recharge
##     faster, the arena joins in (`events`: lights out, a gale, ink, a
##     blizzard, a frenzy) and it calls its horde (it emits
##     Zombie.phase_reached; the run director sends a pack).
##   - Signature moves (`moves`, BossMove building blocks configured in its
##     data): strike patterns, shockwaves, lane charges, beam sweeps, summons,
##     burrowing. Each unlocks at a phase; they take turns.
##   - Ground slam: with the player close it rears up while a ring grows on
##     the floor (the telegraph), then the shockwave hits anyone standing
##     inside the ring. Back out of the ring or jump the shockwave.
##   - Volley (optional): at range it plants its feet, glows, and fires a fan
##     of slow orbs. Strafe between them.
##   - Armour plates (optional): body shots do `armour_share` damage until the
##     plates have soaked `armour_health`; they pop off one by one. Headshots
##     ignore them.
##   - Dazed (BossCharge.dazed): after some moves it stands stunned with a
##     glowing weak spot and takes `exposed_scale` damage.
##   - An entrance roar, and a defeat moment (a short slow-motion burst).
##
## A pulsing ring under its feet marks it in a crowd.

## A HUD line for the run director to show.
signal callout(text: String)
## A BossSummon asks for `count` of `enemy` around `at`; the director appends
## each one it spawns to `into`.
signal summon_requested(enemy: StringName, count: int, at: Zombie, into: Array[Zombie])

## The beat of slow motion when an alpha falls (real seconds, time scale).
const DEFEAT_SECONDS := 0.9
const DEFEAT_TIME_SCALE := 0.35

@export var color := Color(1.0, 0.35, 0.75)
## Its epithet on the boss bar under the name ("THE PRIZE BOOTH BULLY").
@export var title := ""
## Health fractions at which a new phase starts (highest first).
@export var phases := PackedFloat32Array([0.66, 0.33])
## Speed gained per phase (fraction of the base speed).
@export var phase_speed := 0.1
## HUD line for each phase it reaches (index 0 = the first phase change).
@export var phase_callouts := PackedStringArray()
## Seconds it stops to roar at a phase change, and the share of damage it
## takes meanwhile.
@export var phase_roar := 1.6
@export_range(0.0, 1.0) var phase_guard := 0.25
## Moves recharge this much faster per phase reached.
@export var phase_tempo := 0.2

@export_group("Moves")
@export var moves: Array[BossMove] = []
@export var events: Array[BossArenaEvent] = []
## Seconds between the end of one signature move and the start of the next.
@export var move_gap := 1.4

@export_group("Armour")
## Damage its plates soak from body shots before they are gone (0 = none).
@export var armour_health := 0.0
@export_range(0.0, 1.0) var armour_share := 0.55
@export var armour_plates := 3
@export var armour_color := Color(1, 0.85, 0.4)
@export var armour_callout := ""

@export_group("Dazed")
@export var exposed_scale := 1.75
@export var expose_callout := ""

@export_group("Slam")
## The slam starts when the player is within this distance (0 = no slam).
@export var slam_trigger := 4.2
@export var slam_radius := 5.5
@export var slam_windup := 1.15
@export var slam_damage := 26.0
@export var slam_cooldown := 8.0
@export var slam_clip: StringName = &"Roar"
@export var slam_windup_sound: StringName = &"rounds_boss_windup"
@export var slam_sound: StringName = &"rounds_boss_slam"

@export_group("Volley")
## Orbs per volley (0 = no volley).
@export var volley_shots := 0
@export var volley_min_range := 7.0
@export var volley_max_range := 24.0
@export var volley_windup := 1.0
@export var volley_cooldown := 7.5
@export var volley_damage := 8.0
@export var volley_speed := 12.0
## Angle between neighbouring orbs.
@export var volley_spread_degrees := 11.0
## Above 0 the orbs are lobbed (see EnemyProjectile.launch).
@export var volley_arc := 0.0
@export var volley_size := 0.3
@export var volley_clip: StringName = &"Attack"
@export var volley_sound: StringName = &"rounds_boss_volley"

## Times each move was used this fight (move name -> count), for balance logs.
var uses := {}
var _phase := 0
var _move: BossMove
var _rotor := 0
var _gap := 0.0
var _roar_left := 0.0
var _roar_callout := ""
var _entrance := 0.0
var _entered := false
var _exposed_left := 0.0
var _exposed_told := false
var _weak_spot: MeshInstance3D
var _armour_left := 0.0
var _armour_told := false
var _plates: Array[MeshInstance3D] = []
var _told := {}
var _slam_cool := 4.0
var _slam_left := 0.0
var _volley_cool := 3.0
var _volley_left := 0.0
var _aura: MeshInstance3D
var _ring: MeshInstance3D
var _pulse := 0.0

static var _torus: TorusMesh
static var _plate_mesh: BoxMesh
static var _spot_mesh: SphereMesh


func on_ready(z: Zombie) -> void:
	_aura = make_ring(color, 0.9)
	z.add_child(_aura)
	_aura.position.y = 0.06
	_aura.scale = Vector3.ONE * 1.35 * z.data.body_scale
	for m in moves:
		m.reset(self)
	if armour_health > 0.0:
		_armour_left = armour_health
		_add_plates(z)


func on_physics(z: Zombie, delta: float) -> bool:
	_pulse += delta
	if is_instance_valid(_aura):
		var k := 1.3 + 0.12 * sin(_pulse * 4.0)
		_aura.scale = Vector3(k, 1.0, k) * z.data.body_scale
	_tick_events(z, delta)
	if _entrance > 0.0 or (not _entered and z.state == Zombie.State.CHASE):
		return _tick_entrance(z, delta)
	if _roar_left > 0.0:
		return _tick_roar(z, delta)
	if _exposed_left > 0.0:
		return _tick_exposed(z, delta)
	var tempo := (1.0 + phase_tempo * _phase) * _event_tempo()
	z.speed_multiplier = _event_tempo()
	_slam_cool -= delta * tempo
	_volley_cool -= delta * tempo
	for m in moves:
		m.cool -= delta * tempo
	if _move:
		if _move.tick(z, delta):
			return true
		_move = null
		_gap = move_gap
	_gap -= delta * tempo
	if _slam_left > 0.0:
		_tick_slam(z, delta)
		return true
	if _volley_left > 0.0:
		_tick_volley(z, delta)
		return true
	if z.state != Zombie.State.CHASE or not z.target.alive or z.is_winding_up():
		return false
	var d := z.distance_to_target()
	if slam_trigger > 0.0 and _slam_cool <= 0.0 and d <= slam_trigger:
		_begin_slam(z)
		return true
	if _gap <= 0.0 and _start_move(z, d):
		return true
	if volley_shots > 0 and _volley_cool <= 0.0 and d >= volley_min_range and d <= volley_max_range and z.has_line_of_sight():
		_begin_volley(z)
		return true
	return false


func on_hit(z: Zombie, amount: float, at: Vector3, headshot: bool) -> float:
	if _move:
		amount = _move.filter_hit(z, amount, at, headshot)
	if _roar_left > 0.0:
		amount *= phase_guard
	if _exposed_left > 0.0:
		amount *= exposed_scale
	elif _armour_left > 0.0 and not headshot:
		_armour_left -= amount
		amount *= armour_share
		_update_plates(z)
	if _phase < phases.size() and (z.health - amount) / maxf(1.0, z.max_health) <= phases[_phase] and z.health - amount > 0.0:
		# One hit never skips a phase: it lands just under the threshold.
		amount = minf(amount, z.health - z.max_health * (phases[_phase] - 0.01))
		_phase += 1
		z.speed *= 1.0 + phase_speed
		_slam_cool = minf(_slam_cool, 1.5)
		z.enrage(4.0)
		_begin_roar(z)
		z.phase_reached.emit(z, _phase)
	return amount


func on_death(z: Zombie) -> void:
	_slam_left = 0.0
	_volley_left = 0.0
	_drop_ring()
	if is_instance_valid(_aura):
		_aura.queue_free()
	if _move:
		_move.cancel(z)
		_move = null
	for e in events:
		e.stop(z)
	_set_weak_spot(z, false)
	_defeat_moment(z)


## Knocked out of a wind-up (a freeze, a heavy stagger): a signature move
## still winding up is cancelled.
func interrupt(z: Zombie) -> void:
	if _move and _move.is_winding_up():
		_move.cancel(z)
		_move = null
		_gap = move_gap


func is_winding_up() -> bool:
	return _slam_left > 0.0 or _volley_left > 0.0 or (_move != null and _move.is_winding_up())


## Phases reached so far (0 at full health).
func phase() -> int:
	return _phase


## True while it stands dazed with its weak spot glowing.
func is_exposed() -> bool:
	return _exposed_left > 0.0


## Armour left as a fraction (0 when it has none or it is broken).
func armour_fraction() -> float:
	return clampf(_armour_left / armour_health, 0.0, 1.0) if armour_health > 0.0 else 0.0


## Dazes it for `seconds`: it stops, its weak spot glows, and every hit does
## `exposed_scale` damage.
func expose(z: Zombie, seconds: float) -> void:
	_exposed_left = seconds
	z.play_animation(&"Stagger", 0.1)
	_set_weak_spot(z, true)
	Sfx.play_at(&"boss_dazed", z.global_position + Vector3.UP * 2.0, 2.0, 1.0, 14.0)
	if not _exposed_told:
		_exposed_told = true
		_say(expose_callout)


## A direction out of whatever is about to hit a player at `point` (its slam
## ring, its move's lane, a marked strike), zero when safe. For the playtest
## bot, which reads the floor markers the way a player does.
func escape_from(z: Zombie, point: Vector3) -> Vector3:
	if _slam_left > 0.0:
		var away := point - z.global_position
		away.y = 0.0
		if away.length() < slam_radius + 1.0:
			return away.normalized() if away.length() > 0.1 else -z.global_basis.z
	if _move:
		var out := _move.escape_from(z, point)
		if out != Vector3.ZERO:
			return out
	for zone in BossZone.live:
		if zone.is_dangerous() and zone.covers(point, 0.8):
			var away := point - zone.global_position
			away.y = 0.0
			return away.normalized() if away.length() > 0.1 else Vector3.RIGHT
	return Vector3.ZERO


## True when a player at `point` should jump now (a rolling shockwave, a low beam).
func wants_jump(z: Zombie, point: Vector3) -> bool:
	return _move != null and _move.wants_jump(z, point)


# --- signature moves, phases, entrance, defeat -----------------------------------

## Starts the next move in the rotation that is ready. True if one started.
func _start_move(z: Zombie, distance: float) -> bool:
	for i in moves.size():
		var m := moves[(_rotor + i) % moves.size()]
		if m.can_start(z, distance):
			_rotor = (_rotor + i + 1) % moves.size()
			_move = m
			m.begin(z)
			uses[m.move_name] = int(uses.get(m.move_name, 0)) + 1
			if not _told.has(m.move_name):
				_told[m.move_name] = true
				_say(m.callout)
			return true
	return false


func _begin_roar(z: Zombie) -> void:
	if _move:
		_move.cancel(z)
		_move = null
	_slam_left = 0.0
	_volley_left = 0.0
	_drop_ring()
	_exposed_left = 0.0
	_set_weak_spot(z, false)
	_roar_left = phase_roar
	_roar_callout = phase_callouts[_phase - 1] if _phase - 1 < phase_callouts.size() else ""
	z.play_animation(&"Roar", 0.1)
	Sfx.play_at(&"boss_roar", z.global_position + Vector3.UP * 2.0, 4.0, 0.9, 20.0)
	_burst_ring(z, 7.0)
	# The roar shoves a player standing close back out of reach.
	var away := z.target.global_position - z.global_position
	away.y = 0.0
	if away.length() < 6.0:
		z.target.velocity += away.normalized() * 9.0 + Vector3.UP * 3.0
	z.target.add_shake(0.5)


func _tick_roar(z: Zombie, delta: float) -> bool:
	_roar_left -= delta
	z.move_with(Vector3.ZERO)
	z.face_toward(BossMove.flat_to_target(z), delta)
	if _roar_left <= 0.0:
		for e in events:
			if e.phase == _phase:
				e.start(z)
				_say(e.callout)
		_say(_roar_callout)
		_gap = 0.4
		z.play_animation(z.data.move_animation, 0.25)
	return true


## Its first moment in the arena: it stops and roars before the fight starts.
func _tick_entrance(z: Zombie, delta: float) -> bool:
	if not _entered:
		_entered = true
		_entrance = 1.5
		z.play_animation(&"Roar", 0.1)
		Sfx.play_at(&"boss_roar", z.global_position + Vector3.UP * 2.0, 4.0, 1.0, 24.0)
		_burst_ring(z, 5.0)
	_entrance -= delta
	z.move_with(Vector3.ZERO)
	z.face_toward(BossMove.flat_to_target(z), delta)
	if _entrance <= 0.0:
		z.play_animation(z.data.move_animation, 0.25)
	return true


func _tick_exposed(z: Zombie, delta: float) -> bool:
	_exposed_left -= delta
	z.move_with(Vector3.ZERO)
	if is_instance_valid(_weak_spot):
		_weak_spot.scale = Vector3.ONE * (1.0 + 0.25 * sin(_pulse * 14.0)) * 0.42 * z.data.body_scale
	if _exposed_left <= 0.0:
		_set_weak_spot(z, false)
		z.play_animation(z.data.move_animation, 0.25)
	return true


func _tick_events(z: Zombie, delta: float) -> void:
	var player_down := not is_instance_valid(z.target) or not z.target.alive
	for e in events:
		if player_down:
			e.stop(z)
		else:
			e.tick(z, delta)


func _event_tempo() -> float:
	var k := 1.0
	for e in events:
		k *= e.tempo()
	return k


func _say(text: String) -> void:
	if text != "":
		callout.emit(text)


## The glowing weak spot on its chest while it is dazed.
func _set_weak_spot(z: Zombie, on: bool) -> void:
	if not on:
		if is_instance_valid(_weak_spot):
			_weak_spot.queue_free()
		_weak_spot = null
		return
	if is_instance_valid(_weak_spot):
		return
	if _spot_mesh == null:
		_spot_mesh = SphereMesh.new()
		_spot_mesh.radius = 0.5
		_spot_mesh.height = 1.0
	_weak_spot = MeshInstance3D.new()
	_weak_spot.mesh = _spot_mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.95, 0.5)
	_weak_spot.material_override = m
	_weak_spot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	z.add_child(_weak_spot)
	_weak_spot.position = Vector3(0.0, 1.15, 0.38) * z.data.body_scale


## Glowing armour plates on its chest, shoulders and back.
func _add_plates(z: Zombie) -> void:
	if _plate_mesh == null:
		_plate_mesh = BoxMesh.new()
	var m := StandardMaterial3D.new()
	m.albedo_color = armour_color.darkened(0.35)
	m.metallic = 0.7
	m.roughness = 0.3
	m.emission_enabled = true
	m.emission = armour_color
	m.emission_energy_multiplier = 0.9
	var spots := [
		[Vector3(0.0, 1.12, 0.36), Vector3(0.62, 0.5, 0.08)],
		[Vector3(0.5, 1.55, 0.05), Vector3(0.32, 0.12, 0.42)],
		[Vector3(-0.5, 1.55, 0.05), Vector3(0.32, 0.12, 0.42)],
		[Vector3(0.0, 1.2, -0.36), Vector3(0.6, 0.5, 0.08)],
	]
	for i in mini(armour_plates, spots.size()):
		var plate := MeshInstance3D.new()
		plate.mesh = _plate_mesh
		plate.material_override = m
		z.add_child(plate)
		plate.position = spots[i][0] * z.data.body_scale
		plate.scale = spots[i][1] * z.data.body_scale
		_plates.append(plate)


## Pops plates off as the armour wears down; the last one says so.
func _update_plates(z: Zombie) -> void:
	var standing := ceili(armour_fraction() * armour_plates)
	while _plates.size() > standing:
		var plate: MeshInstance3D = _plates.pop_back()
		if is_instance_valid(plate):
			Fx.impact(z.get_parent(), plate.global_position, plate.global_basis.z, armour_color)
			Fx.confetti(z.get_parent(), plate.global_position)
			plate.queue_free()
		Sfx.play_at(&"boss_plate_break", z.global_position + Vector3.UP * 1.5, 3.0, randf_range(0.95, 1.1), 16.0)
	if _armour_left <= 0.0 and not _armour_told:
		_armour_told = true
		_say(armour_callout)


## A ring of light bursting out along the floor (entrance, roar, defeat).
func _burst_ring(z: Zombie, size: float) -> void:
	var ring := make_ring(color, 0.9)
	z.get_parent().add_child(ring)
	ring.global_position = z.global_position + Vector3.UP * 0.1
	ring.scale = Vector3(1.0, 2.0, 1.0)
	var tw := ring.create_tween().set_parallel()
	tw.tween_property(ring, "scale", Vector3(size, 4.0, size), 0.55).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(ring.material_override, "albedo_color:a", 0.0, 0.55)
	tw.chain().tween_callback(ring.queue_free)


## The fall: confetti fountains, a ring of light and a beat of slow motion.
func _defeat_moment(z: Zombie) -> void:
	var at := z.global_position
	for i in 6:
		var a := TAU * i / 6.0
		Fx.confetti(z.get_parent(), at + Vector3(cos(a), 1.2, sin(a)) * 1.6)
	Fx.kill_burst(z.get_parent(), at + Vector3.UP * 1.5)
	_burst_ring(z, 10.0)
	Sfx.play_at(&"boss_defeat", at + Vector3.UP * 1.5, 4.0, 1.0, 30.0)
	Engine.time_scale = DEFEAT_TIME_SCALE
	z.get_tree().create_timer(DEFEAT_SECONDS, true, false, true).timeout.connect(_end_slow_motion)


static func _end_slow_motion() -> void:
	Engine.time_scale = 1.0


# --- slam ------------------------------------------------------------------------

func _begin_slam(z: Zombie) -> void:
	_slam_cool = slam_cooldown * z.special_scale
	_slam_left = slam_windup
	uses[&"slam"] = int(uses.get(&"slam", 0)) + 1
	z.play_animation(slam_clip, 0.1)
	Sfx.play_at(slam_windup_sound, z.global_position + Vector3.UP * 1.6, 2.0, 1.0, 14.0)
	_drop_ring()
	_ring = make_ring(color, 1.0)
	z.get_parent().add_child(_ring)
	_ring.global_position = z.global_position + Vector3.UP * 0.08


func _tick_slam(z: Zombie, delta: float) -> void:
	_slam_left -= delta
	z.move_with(Vector3.ZERO)
	var k := clampf(1.0 - _slam_left / slam_windup, 0.0, 1.0)
	if is_instance_valid(_ring):
		var r := lerpf(0.6, slam_radius, k)
		_ring.scale = Vector3(r, 1.0 + 2.0 * k, r)
	if _slam_left > 0.0:
		return
	var at := z.global_position
	_drop_ring()
	Sfx.play_at(slam_sound, at + Vector3.UP, 4.0, 1.0, 16.0)
	for i in 10:
		var a := TAU * i / 10.0
		Fx.impact(z.get_parent(), at + Vector3(cos(a), 0.0, sin(a)) * slam_radius * 0.8 + Vector3.UP * 0.15, Vector3.UP, color)
	var player := z.target
	var flat := player.global_position - at
	flat.y = 0.0
	if player.alive and flat.length() <= slam_radius and player.is_on_floor():
		player.take_damage(slam_damage * z.damage_scale, at)
	z.play_animation(z.data.move_animation, 0.25)


func _drop_ring() -> void:
	if is_instance_valid(_ring):
		_ring.queue_free()
	_ring = null


# --- volley ----------------------------------------------------------------------

func _begin_volley(z: Zombie) -> void:
	_volley_cool = volley_cooldown * z.special_scale
	_volley_left = volley_windup
	uses[&"volley"] = int(uses.get(&"volley", 0)) + 1
	z.play_animation(volley_clip, 0.1)
	Sfx.play_at(slam_windup_sound, z.global_position + Vector3.UP * 1.6, 0.0, 1.25, 14.0)


func _tick_volley(z: Zombie, delta: float) -> void:
	_volley_left -= delta
	var to := z.target.global_position - z.global_position
	z.face_toward(Vector3(to.x, 0.0, to.z), delta)
	z.move_with(Vector3.ZERO)
	if _volley_left > 0.0:
		return
	var from := z.global_position + Vector3.UP * 1.5 * z.data.body_scale + Vector3(sin(z.rotation.y), 0.0, cos(z.rotation.y)) * 0.6
	var aim := z.target.global_position + Vector3.UP * 0.9 - from
	for i in volley_shots:
		var yaw := deg_to_rad(volley_spread_degrees) * (i - (volley_shots - 1) * 0.5)
		EnemyProjectile.launch(z.get_parent(), from, from + aim.rotated(Vector3.UP, yaw), volley_speed,
			volley_damage * z.damage_scale, color, volley_arc, volley_size, z)
	Sfx.play_at(volley_sound, from, 2.0, 1.0, 14.0)
	z.play_animation(z.data.move_animation, 0.25)


# --- visuals ---------------------------------------------------------------------

## A flat glowing ring of radius 1 (scale it to size).
static func make_ring(tint: Color, alpha: float) -> MeshInstance3D:
	if _torus == null:
		_torus = TorusMesh.new()
		_torus.inner_radius = 0.87
		_torus.outer_radius = 1.0
		_torus.rings = 40
		_torus.ring_segments = 6
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(tint.lightened(0.2), alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if alpha < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	var ring := MeshInstance3D.new()
	ring.mesh = _torus
	ring.material_override = m
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return ring
