class_name YoyoLocoShot
extends Node3D
## The Yo-Yo Loco's yo-yo on its glowing string (scripts/weapons/modes/yoyo_loco_mode.gd).
## It is physical and visible the whole way, the string drawn from the gun's
## muzzle to it:
##
##   OUT     snaps out along the aim at OUT_SPEED, up to max_range; the first
##           zombie on its line takes a full hit (WeaponController.strike:
##           headshots and falloff as for any shot), a wall turns it back
##   SLEEP   (the trigger held since the throw) it stays on that zombie,
##           spinning against it: grind ticks every SLEEP_TICK rising from
##           SLEEP_DPS_START to SLEEP_DPS_TOP over SLEEP_RAMP, the zombie
##           slowed, the string glowing hotter, one round of string wear per
##           SLEEP_ROUND_TIME; it lets go when the trigger is released, the
##           zombie drops, SLEEP_MAX runs out, the string would pass
##           STRING_MAX or the magazine has no wear left
##   DOG     (thrown down the sights) "Walk the Dog": it drops to the floor
##           DOG_DROP ahead and rolls out along it at DOG_SPEED to max_range
##           (a wall or a drop turns it back) and home again; every zombie it
##           rolls past is tripped once per leg (YoyoLocoTrip) for DOG_SCALE
##           of a hit
##   BACK    zips home to the muzzle, speeding up (through scenery: the
##           string reels it straight in)

enum Phase { OUT, SLEEP, DOG_OUT, DOG_BACK, BACK }

const MASK_WORLD := 1
const MASK_ENEMIES := 4
const OUT_SPEED := 46.0
## The return speeds up from BACK_START to BACK_TOP over BACK_ACCEL seconds.
const BACK_START := 16.0
const BACK_TOP := 52.0
const BACK_ACCEL := 0.22
const HOME_DISTANCE := 0.5
## Extra reach (m) beyond a zombie's capsule at which a passing yo-yo still hits.
const GRAZE := 0.12
const SLEEP_TICK := 0.1
const SLEEP_DPS_START := 70.0
const SLEEP_DPS_TOP := 175.0
const SLEEP_RAMP := 1.4
const SLEEP_MAX := 3.0
const SLEEP_ROUND_TIME := 0.42
## Speed multiplier on a 1-mass zombie being ground (heavier ones slow less).
const SLEEP_SLOW := 0.55
const STRING_MAX := 17.0
const DOG_DROP := 1.8
const DOG_SPEED := 17.0
const DOG_SCALE := 0.5
## Flat reach (m) beyond a zombie's capsule at which the rolling yo-yo trips it.
const DOG_REACH := 0.35
## The rolling yo-yo turns for home this close (m) to the player.
const DOG_HOME := 1.6
const STEP_UP := 0.45
const RADIUS := 0.11
const SPIN_OUT := 40.0
const SPIN_SLEEP := 70.0
const STRING_POINTS := 14
const STRING_COLD := Color(0.78, 1.0, 0.25)
const STRING_HOT := Color(1.0, 0.45, 0.12)
const STRING_WHITE := Color(1.0, 0.95, 0.85)
const SPARKS := [Color(0.85, 1.0, 0.35), Color(1.0, 0.4, 0.85), Color(1.0, 1.0, 0.85)]
const HOT_SPARKS := [Color(1.0, 0.55, 0.15), Color(1.0, 0.9, 0.5), Color(1.0, 0.3, 0.1)]
const YOYO_SCENE := "res://art/models/yoyo_loco_yoyo.glb"
const SNAP_SOUND := &"yoyo_snap"
const HIT_SOUND := &"yoyo_hit"
const GRIND_SOUND := &"yoyo_grind_loop"
const TRIP_SOUND := &"yoyo_trip"
const WALL_SOUND := &"yoyo_clack"
const ROLL_SOUND := &"yoyo_roll_loop"

var weapon: WeaponData
var controller: WeaponController
var mode: YoyoLocoMode
var phase := Phase.OUT
var target: Zombie
var _dir := Vector3.FORWARD
var _flat := Vector3.FORWARD
var _travelled := 0.0
var _phase_time := 0.0
var _sleep_time := 0.0
var _tick := 0.0
var _wear := 0.0
var _offset := Vector3.ZERO
var _tripped := {}
var _spin := 0.0
var _spin_rate := SPIN_OUT
var _landed := false
var _hit_any := false
var _model: Node3D
var _string: MeshInstance3D
var _string_mesh: ImmediateMesh
var _points := PackedVector3Array()
var _loop: AudioStreamPlayer3D
var _exclude: Array[RID] = []
## Where the player's eye was at a Walk the Dog's throw.
var _eye := Vector3.ZERO

static var _scene: PackedScene


## Throws the yo-yo from `from` along `dir` (the eye at `eye`); `dog` rolls it
## along the floor instead.
static func launch(parent: Node, from: Vector3, dir: Vector3, eye: Vector3, w: WeaponData, owner_controller: WeaponController,
		owner_mode: YoyoLocoMode, dog: bool) -> YoyoLocoShot:
	var s := YoyoLocoShot.new()
	s.weapon = w
	s.controller = owner_controller
	s.mode = owner_mode
	s._dir = dir.normalized()
	var flat := Vector3(dir.x, 0.0, dir.z)
	s._flat = flat.normalized() if flat.length() > 0.05 else Vector3.FORWARD
	s.phase = Phase.DOG_OUT if dog else Phase.OUT
	parent.add_child(s)
	s.global_position = from
	if dog:
		s._eye = eye
	return s


## Seconds for a tap at a target `distance` metres away: out, and home.
static func round_trip(distance: float) -> float:
	var out := distance / OUT_SPEED
	var accel_dist := (BACK_START + BACK_TOP) * 0.5 * BACK_ACCEL
	var back := BACK_ACCEL + maxf(0.0, distance - accel_dist) / BACK_TOP if distance > accel_dist \
		else sqrt(2.0 * distance / ((BACK_TOP - BACK_START) / BACK_ACCEL))
	return out + back



func _ready() -> void:
	_exclude.append(controller.player.get_rid())
	if _scene == null and ResourceLoader.exists(YOYO_SCENE):
		_scene = load(YOYO_SCENE)
	_model = _scene.instantiate() if _scene else Node3D.new()
	add_child(_model)
	_no_shadows(_model)
	_string_mesh = ImmediateMesh.new()
	_string = MeshInstance3D.new()
	_string.mesh = _string_mesh
	_string.top_level = true
	_string.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_string)
	_string.global_transform = Transform3D.IDENTITY
	_points.resize(STRING_POINTS + 1)
	if phase == Phase.DOG_OUT:
		_start_loop(ROLL_SOUND, -8.0)


## 0-1 how hot a Sleeper is running (0 otherwise).
func heat() -> float:
	return clampf(_sleep_time / SLEEP_RAMP, 0.0, 1.0) if phase == Phase.SLEEP else 0.0


func _physics_process(delta: float) -> void:
	if not is_instance_valid(controller) or not is_instance_valid(controller.player):
		queue_free()
		return
	_phase_time += delta
	match phase:
		Phase.OUT:
			_fly_out(delta)
		Phase.SLEEP:
			_sleep(delta)
		Phase.DOG_OUT, Phase.DOG_BACK:
			_walk(delta)
		Phase.BACK:
			_fly_back(delta)


# --- tap ----------------------------------------------------------------------

func _fly_out(delta: float) -> void:
	var step := minf(OUT_SPEED * delta, weapon.max_range - _travelled)
	var from := global_position
	var to := from + _dir * step
	_travelled += step
	var query := PhysicsRayQueryParameters3D.create(from, to, MASK_WORLD | MASK_ENEMIES)
	query.exclude = _exclude
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var collider = hit["collider"]
		if collider is Zombie and not (collider as Zombie).is_dead():
			_hit(collider, hit["position"])
			return
		_clack(hit)
		return
	var grazed := _graze(from, to)
	if grazed:
		_hit(grazed, _facing(grazed, from))
		return
	global_position = to
	if _travelled >= weapon.max_range - 0.01:
		_turn_back()


## A zombie whose capsule the segment passes within GRAZE of (the yo-yo has size).
func _graze(from: Vector3, to: Vector3) -> Zombie:
	var best: Zombie = null
	var best_t := INF
	for node in get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z == null or z.is_dead():
			continue
		var s := z.data.body_scale
		var a := z.global_position + Vector3.UP * z.data.capsule_radius * s
		var b := z.global_position + Vector3.UP * (z.data.capsule_height - z.data.capsule_radius) * s
		var pair := Geometry3D.get_closest_points_between_segments(from, to, a, b)
		if pair[0].distance_to(pair[1]) <= z.data.capsule_radius * s + GRAZE:
			var t := from.distance_to(pair[0])
			if t < best_t:
				best_t = t
				best = z
	return best


func _hit(z: Zombie, point: Vector3) -> void:
	global_position = point - _dir * RADIUS * 0.6
	_hit_any = true
	var eye := controller.player.aim_transform().origin
	var killed := controller.strike(weapon, z, point, _dir, eye.distance_to(point), 1.0)
	WeaponFx.burst(get_parent(), point, -_dir, SPARKS, 10, 4.0, 0.25, 0.03, 70.0)
	Sfx.play_at(HIT_SOUND, point, -2.0, randf_range(0.95, 1.06))
	if killed or not mode.holding():
		_turn_back()
		return
	# Sleeper: it stays on the zombie, spinning against it.
	target = z
	_offset = z.global_transform.affine_inverse() * global_position
	phase = Phase.SLEEP
	_phase_time = 0.0
	_sleep_time = 0.0
	_tick = 0.0
	_wear = 0.0
	_start_loop(GRIND_SOUND, -6.0)


## Off a wall: a clack, sparks, and home.
func _clack(hit: Dictionary) -> void:
	var at: Vector3 = hit["position"]
	var n: Vector3 = hit["normal"]
	global_position = at + n * RADIUS
	WeaponFx.burst(get_parent(), at, n, SPARKS, 6, 3.0, 0.2, 0.025)
	Sfx.play_at(WALL_SOUND, at, -4.0, randf_range(0.95, 1.08))
	_turn_back()


# --- Sleeper ------------------------------------------------------------------

func _sleep(delta: float) -> void:
	if not is_instance_valid(target) or target.is_dead() or not mode.holding() or _sleep_time >= SLEEP_MAX:
		_turn_back()
		return
	var player := controller.player
	if target.global_position.distance_to(player.global_position) > STRING_MAX:
		_turn_back()
		return
	_sleep_time += delta
	_spin_rate = lerpf(SPIN_OUT, SPIN_SLEEP, heat())
	global_position = target.global_transform * _offset
	target.speed_multiplier *= lerpf(1.0, SLEEP_SLOW, 1.0 / sqrt(maxf(1.0, target.data.mass)))
	_wear += delta
	if _wear >= SLEEP_ROUND_TIME:
		_wear -= SLEEP_ROUND_TIME
		if not mode.wear():
			_turn_back()
			return
	_tick += delta
	if _tick < SLEEP_TICK:
		return
	_tick -= SLEEP_TICK
	var dps := lerpf(SLEEP_DPS_START, SLEEP_DPS_TOP, ease(clampf(_sleep_time / SLEEP_RAMP, 0.0, 1.0), 0.7))
	var dir := (global_position - player.global_position).normalized()
	WeaponFx.burst(get_parent(), global_position, Vector3.UP - dir, HOT_SPARKS if heat() > 0.5 else SPARKS, 4 + int(4 * heat()), 3.0, 0.2, 0.022, 80.0)
	if controller.melee_hit(weapon, target, global_position, dir, dps * SLEEP_TICK, 0.0):
		_turn_back()


# --- Walk the Dog -------------------------------------------------------------

func _walk(delta: float) -> void:
	if not _landed:
		_drop(delta)
		return
	var player := controller.player
	var heading := _flat
	if phase == Phase.DOG_BACK:
		var home := player.global_position - global_position
		home.y = 0.0
		if home.length() <= DOG_HOME:
			_turn_back()
			return
		heading = home.normalized()
	var step := DOG_SPEED * delta
	var from := global_position
	var ahead := from + heading * step
	# Low kerbs and steps are rolled over (the floor snap below); walls turn it.
	var wall := _ray(from + Vector3.UP * 0.3, ahead + heading * RADIUS + Vector3.UP * 0.3)
	if not wall.is_empty():
		if phase == Phase.DOG_OUT:
			_clack(wall)
			_turn_dog()
			return
		_turn_back()
		return
	var floor_y := _floor(ahead)
	if is_nan(floor_y):
		if phase == Phase.DOG_OUT:
			_turn_dog()
		else:
			_turn_back()
		return
	ahead.y = floor_y + RADIUS
	_trip_along(from, ahead)
	global_position = ahead
	_travelled += step
	_spin_rate = DOG_SPEED / RADIUS
	if phase == Phase.DOG_OUT and _travelled >= weapon.max_range:
		_turn_dog()


## The first moment of a Walk the Dog: it drops from the muzzle to the floor
## DOG_DROP ahead of the player, then rolls.
func _drop(delta: float) -> void:
	var land := _eye + _flat * DOG_DROP
	var floor_y := _floor(land, 0.4, 2.4)
	if is_nan(floor_y):
		_turn_back()
		return
	land.y = floor_y + RADIUS
	var to := land - global_position
	var step := OUT_SPEED * 0.5 * delta
	if to.length() <= step:
		global_position = land
		_landed = true
		_travelled = DOG_DROP
		Sfx.play_at(WALL_SOUND, land, -6.0, 0.8)
		return
	global_position += to.normalized() * step


func _turn_dog() -> void:
	phase = Phase.DOG_BACK
	_tripped.clear()


## Height of the floor under `at` (NAN for none from `up` above it to `down` below).
func _floor(at: Vector3, up := STEP_UP, down := 1.2) -> float:
	var hit := _ray(at + Vector3.UP * up, at + Vector3.DOWN * down)
	return NAN if hit.is_empty() else float(hit["position"].y)


func _trip_along(from: Vector3, to: Vector3) -> void:
	var seg := Vector2(to.x - from.x, to.z - from.z)
	var len_sq := seg.length_squared()
	for node in get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z == null or z.is_dead() or _tripped.has(z.get_instance_id()):
			continue
		var base := z.global_position
		if absf(base.y - to.y) > 1.2:
			continue
		var rel := Vector2(base.x - from.x, base.z - from.z)
		var t := clampf(rel.dot(seg) / len_sq, 0.0, 1.0) if len_sq > 0.0001 else 0.0
		var at := Vector2(from.x, from.z) + seg * t
		if at.distance_to(Vector2(base.x, base.z)) <= DOG_REACH + z.data.capsule_radius * z.data.body_scale:
			_trip(z)


func _trip(z: Zombie) -> void:
	_tripped[z.get_instance_id()] = true
	_hit_any = true
	var at := z.global_position + Vector3.UP * 0.25
	var dir := Vector3(_flat.x, 0.0, _flat.z) if phase == Phase.DOG_OUT else -_flat
	WeaponFx.burst(get_parent(), at, Vector3.UP, SPARKS, 8, 3.0, 0.25, 0.03, 70.0)
	Sfx.play_at(TRIP_SOUND, at, -3.0, randf_range(0.95, 1.08))
	YoyoLocoTrip.of(z).apply()
	controller.melee_hit(weapon, z, at, dir, weapon.damage * DOG_SCALE, weapon.knockback * 0.5)


# --- home ---------------------------------------------------------------------

func _turn_back() -> void:
	phase = Phase.BACK
	_phase_time = 0.0
	target = null
	_spin_rate = SPIN_OUT
	_stop_loop()
	Sfx.play_at(SNAP_SOUND, global_position, -7.0, randf_range(1.05, 1.15))


func _fly_back(delta: float) -> void:
	var home := controller.player.view.muzzle_position()
	var to := home - global_position
	var dist := to.length()
	var speed := lerpf(BACK_START, BACK_TOP, clampf(_phase_time / BACK_ACCEL, 0.0, 1.0))
	if dist <= maxf(HOME_DISTANCE, speed * delta):
		mode.on_home(&"catch_hit" if _hit_any else &"catch")
		queue_free()
		return
	global_position += to / dist * speed * delta


# --- look ---------------------------------------------------------------------

func _process(delta: float) -> void:
	_spin = fmod(_spin + _spin_rate * delta, TAU)
	var cam := get_viewport().get_camera_3d()
	var muzzle := controller.player.view.muzzle_position() if is_instance_valid(controller) and is_instance_valid(controller.player) else global_position
	# The yo-yo spins about its axle, square to the string (rolling on its edge for the dog).
	var along := (global_position - muzzle)
	along.y = 0.0
	var fwd := along.normalized() if along.length() > 0.05 else _flat
	var axle := Vector3.UP.cross(fwd).normalized()
	var near := clampf(cam.global_position.distance_to(global_position) / 2.0, 0.35, 1.0) if cam else 1.0
	_model.global_basis = Basis(Vector3.UP, atan2(-axle.z, axle.x)) * Basis(Vector3.RIGHT, -_spin) * Basis.from_scale(Vector3.ONE * near)
	_draw_string(cam, muzzle)


## The glowing string from the muzzle: slack and sagging as it rolls on the
## floor, taut while it flies, taut, buzzing and hotter while it sleeps.
func _draw_string(cam: Camera3D, muzzle: Vector3) -> void:
	if cam == null:
		_string_mesh.clear_surfaces()
		return
	var end := global_position
	var h := heat()
	var sag := 0.0
	var buzz := 0.0
	match phase:
		Phase.DOG_OUT, Phase.DOG_BACK:
			sag = 0.35
		Phase.SLEEP:
			buzz = 0.012 + 0.02 * h
		_:
			sag = 0.04
	var t := Time.get_ticks_msec() * 0.001
	for i in STRING_POINTS + 1:
		var k := float(i) / STRING_POINTS
		var p := muzzle.lerp(end, k)
		p += Vector3.DOWN * sag * sin(k * PI) * minf(1.0, muzzle.distance_to(end) / 6.0)
		p += Vector3.UP * buzz * sin(k * PI) * sin(t * 90.0 + k * 9.0)
		_points[i] = p
	var col := STRING_COLD.lerp(STRING_HOT, h).lerp(STRING_WHITE, maxf(0.0, h - 0.7) / 0.3)
	WeaponFx.begin_ribbons(_string_mesh, WeaponFx.ribbon_material())
	WeaponFx.add_ribbon(_string_mesh, _points, 0.05 + 0.05 * h, Color(col, 0.3 + 0.2 * h), cam.global_position)
	WeaponFx.add_ribbon(_string_mesh, _points, 0.014 + 0.01 * h, Color(col.lerp(Color.WHITE, 0.4), 0.95), cam.global_position)
	WeaponFx.end_ribbons(_string_mesh)


func _start_loop(sound: StringName, volume_db: float) -> void:
	_stop_loop()
	var s := Sfx.stream(sound)
	if s == null:
		return
	if s is AudioStreamWAV and s.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = int(s.get_length() * s.mix_rate)
	_loop = AudioStreamPlayer3D.new()
	_loop.stream = s
	_loop.bus = &"SFX"
	_loop.unit_size = 6.0
	_loop.volume_db = volume_db + Sfx.mix_db(sound)
	add_child(_loop)
	_loop.play()


func _stop_loop() -> void:
	if _loop:
		_loop.queue_free()
		_loop = null


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, MASK_WORLD)
	query.exclude = _exclude
	return get_world_3d().direct_space_state.intersect_ray(query)


## A chest-height point on the side of `z` facing `from` (a graze is a body hit).
static func _facing(z: Zombie, from: Vector3) -> Vector3:
	var flat := Vector3(from.x - z.global_position.x, 0.0, from.z - z.global_position.z)
	var side := flat.normalized() * z.data.capsule_radius * z.data.body_scale if flat.length() > 0.01 else Vector3.ZERO
	return z.global_position + Vector3(side.x, z.data.body_scale, side.z)


static func _no_shadows(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_no_shadows(child)
