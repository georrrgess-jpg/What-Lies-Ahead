class_name TinSoldier
extends Node3D
## The Tin Sergeant's round: a wind-up tin soldier (art/models/tin_soldier.glb).
##
## It is lobbed on the WeaponData's launch velocity, tumbling (the aim arc
## preview shows where it lands). A soldier that strikes a zombie in flight
## hits it for direct_hit_bonus and drops at its feet. On the floor it hops
## upright and winds itself up for WIND_TIME (the key on its back spins, the
## ratchet clicks), then marches: stiff legs, a swinging arm, the key slowly
## unwinding. It marches on the nearest zombie (one already chased by another
## soldier counts SHARE_PENALTY metres further, so a squad spreads over a
## pack) and pops when it reaches it, or when any zombie walks into it: the
## blast hits every zombie within splash_radius (splash_edge_scale at the
## rim; bosses and the heaviest alphas take BOSS_SCALE). The player is never
## hurt: only zombies are hit (WeaponController.melee_hit).
##
## "Fall in!" (TinSergeantMode, aiming): while a rally point is set the squad
## marches to it and forms a ring round it, and only goes for zombies that
## come within RALLY_GUARD of it.
##
## Walking: along the navigation mesh (NavigationServer3D.map_get_path,
## re-planned every REPATH), falling back to straight-line steering when
## there is no path or no map, sliding along walls and stepping up kerbs
## (STEP_UP). A soldier that makes less than STUCK_MIN of headway in a
## STUCK_CHECK window switches to straight steering for a while; after
## STUCK_STRIKES such windows in a row it gives up and pops where it is. Its
## spring runs down after MARCH_LIFE (it slows over the last RUN_DOWN
## seconds) and it pops then too.
##
## A player has at most MAX_SOLDIERS out: one more pops the oldest. Spent
## soldiers are hidden and kept under the level for the next launch (a
## pool), so a long fight makes no new nodes. tools/balance_report.py reads
## these constants.

const MASK_WORLD := 1
const MODEL: PackedScene = preload("res://art/models/tin_soldier.glb")
const MAX_SOLDIERS := 6
const SETTLE_TIME := 0.22
const WIND_TIME := 0.55
const MARCH_LIFE := 12.0
const RUN_DOWN := 1.6
const MARCH_SPEED := 3.3
const TURN_RATE := 10.0
## Steps a second at full speed (two steps to a stride).
const STEP_RATE := 3.6
const SEEK_RANGE := 24.0
const SHARE_PENALTY := 3.0
## Pops when this close (m, flat, plus the zombie's own radius) to its target,
## or to any zombie at all (CONTACT).
const POP_REACH := 0.45
const CONTACT := 0.35
const REACH_UP := 2.0
const SCAN_INTERVAL := 0.2
const REPATH := 0.6
const CORNER := 0.3
const STUCK_CHECK := 0.8
const STUCK_MIN := 0.35
const STUCK_STRIKES := 3
const STRAIGHT_TIME := 1.6
const STEP_UP := 0.45
const FALL_LIMIT := 8.0
const GRAVITY := 18.0
const FLIGHT_MAX := 3.0
const BOUNCE_KEEP := 0.3
const FLY_SPIN := 11.0
## "Fall in!": the ring the squad forms round the flag, how far out the flag
## is guarded, and how long the rally holds after the sights come down.
const FORM_RADIUS := 1.1
const RALLY_GUARD := 4.5
const RALLY_KEEP := 6.0
const BOSS_MASS := 5.0
const BOSS_SCALE := 0.75
const POP_TIME := 0.34
const SEPARATION := 0.45
const TICK_GAP_MS := 70
const TICK_RANGE := 16.0
const WIND_SOUND := &"ts_wind"
const TICK_SOUND := &"ts_tick"
const POP_SOUND := &"ts_pop"
const LAND_SOUND := &"ts_land"
const CONFETTI: Array[Color] = [Color(0.18, 0.37, 0.82), Color(0.89, 0.27, 0.23), Color(0.95, 0.76, 0.23), Color(0.97, 0.95, 0.92)]
const RING_COLOR := Color(0.95, 0.76, 0.23)

enum Phase { FLY, SETTLE, WIND, MARCH, POP, OFF }

var weapon: WeaponData
var controller: WeaponController
var velocity := Vector3.ZERO
var phase := Phase.OFF
## The zombie this soldier is marching on (the squad spreads by it).
var target: Zombie
var _t := 0.0
var _life := 0.0
var _scan := 0.0
var _repath := 0.0
var _path := PackedVector3Array()
var _path_i := 0
var _goal := Vector3.INF
var _straight := 0.0
var _stuck_clock := 0.0
var _stuck_from := Vector3.ZERO
var _strikes := 0
var _fall := 0.0
var _speed := 0.0
var _stride := 0.0
var _key_angle := 0.0
var _exclude: Array[RID] = []
var _model: Node3D
var _parts := {}
var _rest := {}
var _land_from := Quaternion.IDENTITY

static var _live: Array[TinSoldier] = []
static var _pool: Array[TinSoldier] = []
static var _rally := {}
static var _last_tick_ms := 0


## Throws a soldier of `w` from `from` with launch velocity `vel`. A player
## already at MAX_SOLDIERS pops their oldest first.
static func launch(owner_controller: WeaponController, from: Vector3, vel: Vector3, w: WeaponData) -> void:
	var level := owner_controller.player.get_parent()
	if level == null:
		return
	var mine := live(owner_controller)
	if mine.size() >= MAX_SOLDIERS:
		mine[0].pop_now()
	_take(level).begin(owner_controller, w, from, vel)


## A spent soldier kept under `level`, or a new one.
static func _take(level: Node) -> TinSoldier:
	while not _pool.is_empty():
		var s: TinSoldier = _pool.pop_back()
		if is_instance_valid(s) and s.get_parent() == level:
			return s
	var fresh := TinSoldier.new()
	level.add_child(fresh)
	return fresh


## `owner_controller`'s soldiers still out (flying, winding or marching), oldest first.
static func live(owner_controller: WeaponController) -> Array[TinSoldier]:
	var out: Array[TinSoldier] = []
	for s in _live.duplicate():
		if not is_instance_valid(s) or s.phase == Phase.POP or s.phase == Phase.OFF:
			_live.erase(s)
		elif s.controller == owner_controller:
			out.append(s)
	return out


## Plants (or moves) `owner_controller`'s "Fall in!" point at `at`; it holds
## RALLY_KEEP seconds after the last call.
static func set_rally(owner_controller: WeaponController, at: Vector3) -> void:
	_rally[owner_controller] = [at, Time.get_ticks_msec() + int(RALLY_KEEP * 1000.0)]


## The rally point, or Vector3.INF when there is none.
static func rally_of(owner_controller: WeaponController) -> Vector3:
	var entry: Array = _rally.get(owner_controller, [])
	if entry.is_empty():
		return Vector3.INF
	if Time.get_ticks_msec() > int(entry[1]):
		_rally.erase(owner_controller)
		return Vector3.INF
	return entry[0]


## Seconds the rally still holds (0 when none).
static func rally_left(owner_controller: WeaponController) -> float:
	if rally_of(owner_controller) == Vector3.INF:
		return 0.0
	return maxf(0.0, (int(_rally[owner_controller][1]) - Time.get_ticks_msec()) / 1000.0)


static func clear_rally(owner_controller: WeaponController) -> void:
	_rally.erase(owner_controller)


func _ready() -> void:
	_model = MODEL.instantiate()
	add_child(_model)
	for part in ["Body", "LegL", "LegR", "ArmL", "ArmR", "Key"]:
		var node := _model.find_child(part, true, false) as Node3D
		if node:
			_parts[part] = node
			_rest[part] = node.transform
	for node in _model.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _exit_tree() -> void:
	_live.erase(self)
	_pool.erase(self)


## Sends this soldier out (fresh or from the pool).
func begin(owner_controller: WeaponController, w: WeaponData, from: Vector3, vel: Vector3) -> void:
	weapon = w
	controller = owner_controller
	velocity = vel
	phase = Phase.FLY
	target = null
	_t = 0.0
	_life = 0.0
	_scan = randf() * SCAN_INTERVAL
	_repath = 0.0
	_path = PackedVector3Array()
	_goal = Vector3.INF
	_straight = 0.0
	_stuck_clock = 0.0
	_strikes = 0
	_fall = 0.0
	_speed = 0.0
	_stride = 0.0
	_exclude = [owner_controller.player.get_rid()]
	_pool.erase(self)
	_live.append(self)
	global_position = from
	rotation = Vector3(0.0, atan2(vel.x, vel.z) + PI, 0.0)
	_model.transform = Transform3D.IDENTITY
	for part in _rest:
		(_parts[part] as Node3D).transform = _rest[part]
		(_parts[part] as Node3D).visible = true
	visible = true
	set_physics_process(true)
	set_process(true)


func _physics_process(delta: float) -> void:
	_t += delta
	match phase:
		Phase.FLY:
			_fly(delta)
		Phase.SETTLE:
			if _t >= SETTLE_TIME:
				phase = Phase.WIND
				_t = 0.0
				Sfx.play_at(WIND_SOUND, global_position + Vector3.UP * 0.3, -5.0, randf_range(0.95, 1.08), 9.0)
		Phase.WIND:
			if _t >= WIND_TIME:
				phase = Phase.MARCH
				_t = 0.0
				_stuck_from = global_position
		Phase.MARCH:
			_march(delta)


func _process(delta: float) -> void:
	match phase:
		Phase.FLY:
			_model.rotate_object_local(Vector3.RIGHT, FLY_SPIN * delta)
		Phase.SETTLE:
			_pose_settle()
		Phase.WIND:
			_pose_wind(delta)
		Phase.MARCH:
			_pose_march(delta)
		Phase.POP:
			_pose_pop()


# --- flight ----------------------------------------------------------------------

func _fly(delta: float) -> void:
	if _t >= FLIGHT_MAX:
		_land_at(global_position)
		return
	velocity.y -= weapon.projectile_gravity * delta
	var from := global_position
	var to := from + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, MASK_WORLD | 4)
	query.exclude = _exclude
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = to
		return
	var z := hit["collider"] as Zombie
	if z and not z.is_dead():
		_direct(z, Vector3(hit["position"]))
		return
	var normal: Vector3 = hit["normal"]
	if normal.y >= 0.6:
		_land_at(Vector3(hit["position"]))
		return
	global_position = Vector3(hit["position"]) + normal * 0.08
	velocity = velocity.bounce(normal) * BOUNCE_KEEP
	Sfx.play_at(LAND_SOUND, global_position, -8.0, 1.3, 9.0)


## Struck a zombie in flight: a clonk on the head, then it drops at its feet
## (and, wound, pops on it straight away).
func _direct(z: Zombie, at: Vector3) -> void:
	var dir := velocity.normalized()
	if weapon.direct_hit_bonus > 0.0 and is_instance_valid(controller):
		controller.melee_hit(weapon, z, at, dir, weapon.direct_hit_bonus, 1.5)
	Sfx.play_at(LAND_SOUND, at, 0.0, 0.8, 11.0)
	target = z
	var back := (global_position - z.global_position).slide(Vector3.UP)
	back = back.normalized() if back.length() > 0.05 else -dir.slide(Vector3.UP).normalized()
	_land_at(z.global_position + back * (0.4 + z.data.capsule_radius * z.data.body_scale))


## Lands on the floor below `at`, then hops upright and winds up.
func _land_at(at: Vector3) -> void:
	var ground := _floor_below(at + Vector3.UP * 0.5, 5.0)
	global_position = ground if ground != Vector3.INF else at
	_land_from = _model.quaternion
	phase = Phase.SETTLE
	_t = 0.0
	Sfx.play_at(LAND_SOUND, global_position, -3.0, randf_range(0.95, 1.08), 9.0)
	WeaponFx.burst(get_parent(), global_position + Vector3.UP * 0.05, Vector3.UP, CONFETTI, 5, 1.8, 0.3, 0.035, 70.0, Vector3(0, -5.0, 0))


# --- marching ---------------------------------------------------------------------

func _march(delta: float) -> void:
	_life += delta
	if _life >= MARCH_LIFE or not is_instance_valid(controller):
		pop_now()
		return
	_scan -= delta
	if _scan <= 0.0:
		_scan = SCAN_INTERVAL
		if _choose_goal():
			return
	var run := clampf((MARCH_LIFE - _life) / RUN_DOWN, 0.35, 1.0)
	var want := 0.0
	var dir := Vector3.ZERO
	if _goal != Vector3.INF:
		var to := (_goal - global_position).slide(Vector3.UP)
		if target and is_instance_valid(target) and to.length() <= POP_REACH + target.data.capsule_radius * target.data.body_scale:
			pop_now()
			return
		if to.length() > 0.2:
			dir = _steer()
			want = MARCH_SPEED * run
	_speed = move_toward(_speed, want, delta * 12.0)
	dir += _separation()
	if dir.length() > 0.01:
		var face := atan2(dir.x, dir.z) + PI
		rotation.y = lerp_angle(rotation.y, face, 1.0 - exp(-TURN_RATE * delta))
	_move(-global_transform.basis.z * _speed * delta, delta)
	_check_stuck(delta)


## Picks the goal: a zombie to march on, or a place in the ring round the
## rally flag. Returns true when the soldier popped (a zombie walked into it).
func _choose_goal() -> bool:
	var rally := rally_of(controller)
	var best: Zombie = null
	var best_score := INF
	var here := global_position
	for node in get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z == null or z.is_dead():
			continue
		var p := z.global_position
		if absf(p.y - here.y) > REACH_UP:
			continue
		var d := Vector2(p.x - here.x, p.z - here.z).length()
		if d <= CONTACT + z.data.capsule_radius * z.data.body_scale:
			target = z
			pop_now()
			return true
		if rally != Vector3.INF:
			if Vector2(p.x - rally.x, p.z - rally.z).length() > RALLY_GUARD:
				continue
		elif d > SEEK_RANGE:
			continue
		var score := d + SHARE_PENALTY * _chasers(z)
		if score < best_score:
			best_score = score
			best = z
	target = best
	var goal := Vector3.INF
	if best:
		goal = best.global_position
	elif rally != Vector3.INF:
		goal = rally + _ring_slot()
	if goal != Vector3.INF and (_goal == Vector3.INF or goal.distance_to(_goal) > 1.0):
		_repath = 0.0
	_goal = goal
	return false


## Other soldiers of this player marching on `z`.
func _chasers(z: Zombie) -> int:
	var n := 0
	for s in _live:
		if s != self and is_instance_valid(s) and s.target == z and s.controller == controller:
			n += 1
	return n


## This soldier's place in the ring round the flag.
func _ring_slot() -> Vector3:
	var squad := live(controller)
	var i := maxi(0, squad.find(self))
	var a := TAU * float(i) / maxf(1.0, float(squad.size())) + 0.4
	return Vector3(cos(a), 0.0, sin(a)) * FORM_RADIUS


## The way to go: the next corner of the navigation path, or straight at the goal.
func _steer() -> Vector3:
	var here := global_position
	var straight := (_goal - here).slide(Vector3.UP).normalized()
	if _straight > 0.0:
		return straight
	_repath -= get_physics_process_delta_time()
	if _repath <= 0.0:
		_repath = REPATH
		_path = PackedVector3Array()
		_path_i = 0
		var map := get_world_3d().navigation_map
		if NavigationServer3D.map_get_iteration_id(map) > 0:
			_path = NavigationServer3D.map_get_path(map, here, _goal, true)
			_path_i = 1
	while _path_i < _path.size() and Vector2(_path[_path_i].x - here.x, _path[_path_i].z - here.z).length() < CORNER:
		_path_i += 1
	if _path_i >= _path.size():
		return straight
	var to := (_path[_path_i] - here).slide(Vector3.UP)
	return to.normalized() if to.length() > 0.01 else straight


## A nudge away from squadmates standing too close.
func _separation() -> Vector3:
	var push := Vector3.ZERO
	for s in _live:
		if s == self or not is_instance_valid(s) or s.phase != Phase.MARCH:
			continue
		var away := (global_position - s.global_position).slide(Vector3.UP)
		var d := away.length()
		if d < SEPARATION and d > 0.001:
			push += away / d * (1.0 - d / SEPARATION)
	return push


## Moves by `step` along the floor: slides along walls, steps up kerbs, falls off ledges.
func _move(step: Vector3, delta: float) -> void:
	var space := get_world_3d().direct_space_state
	var here := global_position
	if step.length() > 0.0005:
		var chest := here + Vector3.UP * 0.3
		var q := PhysicsRayQueryParameters3D.create(chest, chest + step.normalized() * (step.length() + 0.18), MASK_WORLD)
		var wall := space.intersect_ray(q)
		if not wall.is_empty():
			var n: Vector3 = wall["normal"]
			if n.y < 0.6:
				step = step.slide(Vector3(n.x, 0.0, n.z).normalized())
	var next := here + step
	var ground := _floor_below(next + Vector3.UP * STEP_UP, STEP_UP + maxf(0.3, -_fall * delta + 0.1))
	if ground != Vector3.INF:
		next.y = ground.y
		_fall = 0.0
	else:
		_fall -= GRAVITY * delta
		next.y += _fall * delta
		if _fall < -FALL_LIMIT * 2.0:
			_retire()
			return
	global_position = next


func _floor_below(from: Vector3, depth: float) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * depth, MASK_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or Vector3(hit["normal"]).y < 0.5:
		return Vector3.INF
	return hit["position"]


## Headway check: blocked windows switch to straight steering, too many pop it.
func _check_stuck(delta: float) -> void:
	_straight = maxf(0.0, _straight - delta)
	_stuck_clock += delta
	if _stuck_clock < STUCK_CHECK:
		return
	var moved := (global_position - _stuck_from).slide(Vector3.UP).length()
	var trying := _speed > MARCH_SPEED * 0.3
	_stuck_clock = 0.0
	_stuck_from = global_position
	if not trying or moved >= STUCK_MIN:
		_strikes = 0
		return
	_strikes += 1
	if _strikes >= STUCK_STRIKES:
		pop_now()
		return
	_straight = STRAIGHT_TIME if _straight <= 0.0 else 0.0
	_repath = 0.0


# --- the pop -------------------------------------------------------------------

## Pops now: the blast hits every zombie in splash_radius.
func pop_now() -> void:
	if phase == Phase.POP or phase == Phase.OFF:
		return
	if phase == Phase.FLY:
		var ground := _floor_below(global_position + Vector3.UP * 0.3, 4.0)
		if ground != Vector3.INF:
			global_position = ground
	phase = Phase.POP
	_t = 0.0
	_live.erase(self)
	_model.quaternion = Quaternion.IDENTITY
	var centre := global_position + Vector3.UP * 0.35
	Sfx.play_at(POP_SOUND, centre, 0.0, randf_range(0.94, 1.08), 12.0)
	WeaponFx.flash(get_parent(), centre, CONFETTI[2], 1.0, 0.16)
	WeaponFx.burst(get_parent(), centre, Vector3.UP, CONFETTI, 22, 5.0, 0.8, 0.05, 65.0, Vector3(0, -7.0, 0))
	WeaponFx.shockwave(get_parent(), global_position + Vector3.UP * 0.1, RING_COLOR, weapon.splash_radius, 0.8)
	_blast()


func _blast() -> void:
	if not is_instance_valid(controller):
		return
	var r := maxf(0.1, weapon.splash_radius)
	for node in get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z == null or z.is_dead():
			continue
		var flat := Vector2(z.global_position.x - global_position.x, z.global_position.z - global_position.z).length()
		var reach := r + z.data.capsule_radius * z.data.body_scale * 0.5
		if flat > reach or absf(z.global_position.y - global_position.y) > REACH_UP:
			continue
		var k := 1.0 - clampf(flat / reach, 0.0, 1.0)
		var dmg := weapon.damage * lerpf(weapon.splash_edge_scale, 1.0, k)
		if z.rank == Zombie.RANK_BOSS or z.data.mass >= BOSS_MASS:
			dmg *= BOSS_SCALE
		var away := (z.global_position - global_position).slide(Vector3.UP)
		away = away.normalized() if away.length() > 0.05 else -global_transform.basis.z
		var chest := z.global_position + Vector3.UP * 1.0 * z.data.body_scale
		controller.melee_hit(weapon, z, chest - away * 0.3, away, dmg, weapon.splash_push * k)


## Hidden and parked for the next launch.
func _retire() -> void:
	phase = Phase.OFF
	_live.erase(self)
	target = null
	visible = false
	set_physics_process(false)
	set_process(false)
	if not _pool.has(self):
		_pool.append(self)


# --- poses ---------------------------------------------------------------------

## The hop upright: the tumble rights itself on a springy arc with a squash.
func _pose_settle() -> void:
	var u := clampf(_t / SETTLE_TIME, 0.0, 1.0)
	_model.quaternion = _land_from.slerp(Quaternion.IDENTITY, _ease_out_back(u))
	_model.position = Vector3(0.0, 0.14 * sin(PI * u), 0.0)
	var squash := 0.16 * sin(PI * clampf((u - 0.7) / 0.3, 0.0, 1.0))
	_model.scale = Vector3(1.0 + squash, 1.0 - squash, 1.0 + squash)


## Winding up: standing to attention, the key whirring round, a shudder per click.
func _pose_wind(delta: float) -> void:
	_model.transform = Transform3D.IDENTITY
	_key_angle += delta * 26.0
	_turn_key()
	var click := pow(maxf(0.0, sin(_t * 40.0)), 8.0)
	_model.position.y = 0.01 * click
	_model.rotation.z = 0.03 * click * (1.0 if fmod(_t, 0.2) < 0.1 else -1.0)


## Marching: stiff straight legs and the free arm swinging, a bob per step and
## a little roll; the key unwinds with the stride. Standing, it marks time.
func _pose_march(delta: float) -> void:
	var pace := _speed / MARCH_SPEED
	var marking := pace < 0.2
	var rate := STEP_RATE * (0.7 if marking else maxf(0.5, pace))
	var before := int(_stride / PI)
	_stride += delta * rate * PI
	if int(_stride / PI) != before:
		_tick()
	var s := sin(_stride)
	var swing := deg_to_rad(30.0) * (0.35 if marking else 1.0)
	_place("LegL", Vector3(swing * s, 0.0, 0.0))
	_place("LegR", Vector3(-swing * s, 0.0, 0.0))
	_place("ArmL", Vector3(-deg_to_rad(34.0) * s * (0.4 if marking else 1.0), 0.0, deg_to_rad(-4.0)))
	_place("ArmR", Vector3(deg_to_rad(4.0) * s, 0.0, 0.0))
	var lift := absf(s)
	_model.transform = Transform3D(Basis(Vector3.BACK, deg_to_rad(3.5) * s), Vector3(0.0, 0.028 * lift, 0.0))
	_key_angle -= delta * (2.5 + 5.0 * pace)
	_turn_key()


## One tin tick per step, thinned out across the squad so a crowd of them
## stays a patter.
func _tick() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_tick_ms < TICK_GAP_MS:
		return
	var cam := get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_to(global_position) > TICK_RANGE:
		return
	_last_tick_ms = now
	Sfx.play_at(TICK_SOUND, global_position + Vector3.UP * 0.1, -12.0, randf_range(0.9, 1.15), 6.0)


## The pop: it jumps and swells, the key flies off spinning, then it is gone.
func _pose_pop() -> void:
	var u := clampf(_t / POP_TIME, 0.0, 1.0)
	var swell := 1.0 + 0.4 * sin(PI * minf(1.0, u * 1.4))
	var shrink := 1.0 - _ease_in_back(clampf((u - 0.55) / 0.45, 0.0, 1.0))
	_model.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * maxf(0.001, swell * shrink)), Vector3(0.0, 0.3 * sin(PI * u), 0.0))
	var key := _parts.get("Key") as Node3D
	if key:
		var rest: Transform3D = _rest["Key"]
		key.transform = Transform3D(rest.basis * Basis(Vector3.BACK, u * 30.0), rest.origin + Vector3(0.0, 0.9 * u, 0.35 * u))
	if u >= 1.0:
		_retire()


func _turn_key() -> void:
	var key := _parts.get("Key") as Node3D
	if key:
		key.transform = _rest["Key"] * Transform3D(Basis(Vector3.BACK, _key_angle), Vector3.ZERO)


func _place(part: String, euler: Vector3) -> void:
	var node := _parts.get(part) as Node3D
	if node:
		node.transform = _rest[part] * Transform3D(Basis.from_euler(euler), Vector3.ZERO)


static func _ease_out_back(u: float) -> float:
	var c := 1.70158
	return 1.0 + (c + 1.0) * pow(u - 1.0, 3.0) + c * pow(u - 1.0, 2.0)


static func _ease_in_back(u: float) -> float:
	var c := 1.70158
	return (c + 1.0) * u * u * u - c * u * u
