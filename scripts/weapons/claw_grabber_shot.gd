class_name ClawGrabberShot
extends Node3D
## The Claw Grabber's claw on its cable (scripts/weapons/modes/claw_grabber_mode.gd),
## physical and visible the whole way, the cable drawn from the gun's chute:
##
##   OUT     shoots out along the aim at OUT_SPEED, prongs open, up to
##           max_range. The first zombie on its line takes the hit
##           (WeaponController.strike: headshots and falloff as for any shot).
##   YANK    a zombie it can lift (not heavy, not a boss, not emerging) is
##           grabbed: the prongs snap shut, it is Prized and dragged to the
##           player's feet (ClawPrize), the claw riding on it, then dropped
##           stunned and the claw lets go
##   LATCH   a heavy or boss, a wall or the floor: the claw grips and waits
##           a beat (DECIDE after the shot). Trigger still held: the grapple
##           (REEL). Let go (or no grapple ready): a heavy's claw slips off it
##           (it is still Prized and staggered), a wall's lets go, and it
##           comes home
##   REEL    the claw holds on while the player is reeled toward it
##           (Player.reel_to, to the spot ClawGrabberReel.landing allows);
##           the grapple then cools down (ClawGrabberMode.GRAPPLE_COOLDOWN)
##   BACK    reels home to the chute, speeding up (through scenery: the
##           cable pulls it straight in)

enum Phase { OUT, YANK, LATCH, REEL, BACK }

const MASK_WORLD := 1
const MASK_ENEMIES := 4
const OUT_SPEED := 52.0
## The return speeds up from BACK_START to BACK_TOP over BACK_ACCEL seconds.
const BACK_START := 18.0
const BACK_TOP := 60.0
const BACK_ACCEL := 0.2
const HOME_DISTANCE := 0.5
## Extra reach (m) beyond a zombie's capsule at which the claw still grabs it.
const GRAZE := 0.16
## Seconds from the shot after which a held trigger means "reel me in".
const DECIDE := 0.16
## Reel speed (m/s) and the longest a reel lasts (s).
const REEL_SPEED := 19.0
const REEL_TIME := 1.1
## Where the reel stops: off a wall (m along its normal), short of a heavy (m past its capsule).
const WALL_STAND := 0.75
const HEAVY_STAND := 1.5
## Zombies this heavy or heavier are never lifted (Bruisers and up, as for the Teacup Twister).
const LIFT_MASS := 2.5
const CLAW_SCENE := "res://art/models/claw_grabber_claw.glb"
## Prong angles (degrees about their knuckles): open in flight, shut on a grab.
const PRONG_OPEN := -28.0
const PRONG_SHUT := 16.0
const CABLE_POINTS := 14
const CABLE := Color(0.82, 0.86, 0.95)
const CABLE_GLOW := Color(0.22, 0.94, 1.0)
const SPARKS := [Color(0.22, 0.94, 1.0), Color(1.0, 0.31, 0.64), Color(1.0, 0.96, 0.88)]
const GRAB_SOUND := &"clw_grab"
const CLANK_SOUND := &"clw_clank"
const SLIP_SOUND := &"clw_slip"
const REEL_SOUND := &"clw_reel"
const HOME_SOUND := &"clw_home"

var weapon: WeaponData
var controller: WeaponController
var mode: ClawGrabberMode
var phase := Phase.OUT
var target: Zombie
var _dir := Vector3.FORWARD
var _travelled := 0.0
var _age := 0.0
var _phase_time := 0.0
var _anchor := Vector3.ZERO
var _normal := Vector3.UP
var _offset := Vector3.ZERO
var _shut := 0.0
var _hit_any := false
var _model: Node3D
var _prongs: Array[Node3D] = []
var _prong_rest: Array[Transform3D] = []
var _cable: MeshInstance3D
var _cable_mesh: ImmediateMesh
var _points := PackedVector3Array()
var _exclude: Array[RID] = []

static var _scene: PackedScene


## Shoots the claw from `from` along `dir`.
static func launch(parent: Node, from: Vector3, dir: Vector3, w: WeaponData, owner_controller: WeaponController,
		owner_mode: ClawGrabberMode) -> ClawGrabberShot:
	var s := ClawGrabberShot.new()
	s.weapon = w
	s.controller = owner_controller
	s.mode = owner_mode
	s._dir = dir.normalized()
	parent.add_child(s)
	s.global_position = from
	return s


## Seconds for a shot at a target `distance` metres away: out, and home.
static func round_trip(distance: float) -> float:
	var out := distance / OUT_SPEED
	var accel_dist := (BACK_START + BACK_TOP) * 0.5 * BACK_ACCEL
	if distance > accel_dist:
		return out + BACK_ACCEL + (distance - accel_dist) / BACK_TOP
	var a := (BACK_TOP - BACK_START) / BACK_ACCEL
	return out + (sqrt(BACK_START * BACK_START + 2.0 * a * distance) - BACK_START) / a


## True for a zombie the claw cannot lift (it reels the player to it instead).
static func too_heavy(z: Zombie) -> bool:
	return z.data.heavy or z.data.mass >= LIFT_MASS or z.rank == Zombie.RANK_BOSS


func _ready() -> void:
	_exclude.append(controller.player.get_rid())
	if _scene == null and ResourceLoader.exists(CLAW_SCENE):
		_scene = load(CLAW_SCENE)
	_model = _scene.instantiate() if _scene else Node3D.new()
	add_child(_model)
	_no_shadows(_model)
	for i in 3:
		var p := _model.find_child("Prong%d" % i, true, false) as Node3D
		if p:
			_prongs.append(p)
			_prong_rest.append(p.transform)
	_cable_mesh = ImmediateMesh.new()
	_cable = MeshInstance3D.new()
	_cable.mesh = _cable_mesh
	_cable.top_level = true
	_cable.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_cable)
	_cable.global_transform = Transform3D.IDENTITY
	_points.resize(CABLE_POINTS + 1)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(controller) or not is_instance_valid(controller.player):
		queue_free()
		return
	_age += delta
	_phase_time += delta
	match phase:
		Phase.OUT:
			_fly_out(delta)
		Phase.YANK:
			_yank()
		Phase.LATCH:
			_latch()
		Phase.REEL:
			_reel()
		Phase.BACK:
			_fly_back(delta)


# --- out ----------------------------------------------------------------------

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
		_grip_surface(hit)
		return
	var grazed := _graze(from, to)
	if grazed:
		_hit(grazed, _facing(grazed, from))
		return
	global_position = to
	if _travelled >= weapon.max_range - 0.01:
		_turn_back()


## A zombie whose capsule the segment passes within GRAZE of (the claw has size).
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
	global_position = point - _dir * 0.1
	_hit_any = true
	var eye := controller.player.aim_transform().origin
	var killed := controller.strike(weapon, z, point, _dir, eye.distance_to(point), 1.0)
	WeaponFx.burst(get_parent(), point, -_dir, SPARKS, 10, 4.0, 0.25, 0.03, 70.0)
	Sfx.play_at(GRAB_SOUND, point, -1.0, randf_range(0.96, 1.05))
	if killed:
		_turn_back()
		return
	var prize := ClawPrize.of(z)
	prize.prize()
	target = z
	_offset = z.global_transform.affine_inverse() * global_position
	if not too_heavy(z) and prize.grab():
		phase = Phase.YANK
		_phase_time = 0.0
		mode.grabbed(z)
		return
	# Too big to lift (or not liftable right now): the claw grips and waits a beat.
	_latch_on(global_position, -_dir)


func _grip_surface(hit: Dictionary) -> void:
	var at: Vector3 = hit["position"]
	var n: Vector3 = hit["normal"]
	global_position = at + n * 0.08
	WeaponFx.burst(get_parent(), at, n, SPARKS, 6, 3.0, 0.2, 0.025)
	Sfx.play_at(CLANK_SOUND, at, -3.0, randf_range(0.95, 1.06))
	target = null
	_latch_on(at, n)


func _latch_on(at: Vector3, normal: Vector3) -> void:
	_anchor = at
	_normal = normal
	phase = Phase.LATCH
	_phase_time = 0.0


# --- the grab ---------------------------------------------------------------------

## The claw rides on the carried zombie until it is dropped.
func _yank() -> void:
	if not is_instance_valid(target) or target.is_dead():
		_turn_back()
		return
	global_position = target.global_transform * _offset
	var prize := target.get_node_or_null(ClawPrize.NODE_NAME) as ClawPrize
	if prize == null or not prize.is_carried():
		_turn_back()


# --- the grapple ------------------------------------------------------------------

func _latch() -> void:
	if is_instance_valid(target):
		if target.is_dead():
			_turn_back()
			return
		global_position = target.global_transform * _offset
	if _age < DECIDE and mode.holding():
		return
	if mode.holding() and mode.grapple_ready() and _start_reel():
		return
	# Off a heavy, or a grapple that is not ready or has nowhere safe to go: it slips.
	if is_instance_valid(target) or mode.holding():
		_slip()
	_turn_back()


## Reels the player toward the grip if ClawGrabberReel finds a safe spot.
func _start_reel() -> bool:
	var player := controller.player
	var goal: Vector3
	if is_instance_valid(target):
		var back := player.global_position - target.global_position
		back.y = 0.0
		back = back.normalized() if back.length() > 0.05 else -_dir
		goal = target.global_position + back * (target.data.capsule_radius * target.data.body_scale + HEAVY_STAND)
	else:
		goal = _anchor + _normal * WALL_STAND
	var land := ClawGrabberReel.landing(player, goal)
	if land == Vector3.INF:
		return false
	var flat := Vector2(land.x - player.global_position.x, land.z - player.global_position.z).length()
	if not player.reel_to(land, REEL_SPEED, minf(REEL_TIME, flat / REEL_SPEED * 1.6 + 0.15)):
		return false
	phase = Phase.REEL
	_phase_time = 0.0
	mode.grappled()
	# Reeled in on a heavy: the yank knocks it out of its swing (bosses shrug it off).
	if is_instance_valid(target) and target.rank != Zombie.RANK_BOSS:
		target.interrupt()
	Sfx.play(REEL_SOUND, -3.0, randf_range(0.97, 1.03))
	return true


func _reel() -> void:
	if is_instance_valid(target) and not target.is_dead():
		global_position = target.global_transform * _offset
	if not controller.player.is_reeling():
		_turn_back()


## The claw slides off a zombie too big to lift (a real claw machine's
## favourite trick), or off a grip it cannot reel the player to: sparks and a squeal.
func _slip() -> void:
	Sfx.play_at(SLIP_SOUND, global_position, -3.0, randf_range(0.95, 1.05))
	WeaponFx.burst(get_parent(), global_position, Vector3.UP, SPARKS, 8, 2.5, 0.3, 0.03, 90.0)


# --- home ---------------------------------------------------------------------

func _turn_back() -> void:
	if phase == Phase.REEL and controller.player.is_reeling():
		controller.player.stop_reel()
	phase = Phase.BACK
	_phase_time = 0.0
	target = null


func _fly_back(delta: float) -> void:
	var home := controller.player.view.muzzle_position()
	var to := home - global_position
	var dist := to.length()
	var speed := lerpf(BACK_START, BACK_TOP, clampf(_phase_time / BACK_ACCEL, 0.0, 1.0))
	if dist <= maxf(HOME_DISTANCE, speed * delta):
		Sfx.play(HOME_SOUND, -8.0, randf_range(0.97, 1.05))
		mode.on_home(&"catch_hit" if _hit_any else &"catch")
		queue_free()
		return
	global_position += to / dist * speed * delta


## Lets go of whatever the claw holds (the gun was put away).
func release() -> void:
	if phase == Phase.YANK and is_instance_valid(target):
		var prize := target.get_node_or_null(ClawPrize.NODE_NAME) as ClawPrize
		if prize:
			prize.drop()
	if phase == Phase.REEL:
		controller.player.stop_reel()


# --- look ---------------------------------------------------------------------

func _process(delta: float) -> void:
	if not is_instance_valid(controller) or not is_instance_valid(controller.player):
		return
	var cam := get_viewport().get_camera_3d()
	var muzzle := controller.player.view.muzzle_position()
	# Points away from the gun along the cable; prongs open in flight, shut on a grip.
	var along := global_position - muzzle
	var fwd := along.normalized() if along.length() > 0.05 else _dir
	if phase == Phase.OUT:
		fwd = _dir
	var up := Vector3.UP if absf(fwd.y) < 0.95 else Vector3.RIGHT
	_model.global_basis = Basis.looking_at(fwd, up)
	var shut := 0.0 if phase == Phase.OUT else (1.0 if phase in [Phase.YANK, Phase.LATCH, Phase.REEL] else 0.4)
	_shut = lerpf(_shut, shut, 1.0 - exp(-24.0 * delta))
	_pose_prongs(lerpf(PRONG_OPEN, PRONG_SHUT, _shut))
	_draw_cable(cam, muzzle)


func _pose_prongs(degrees: float) -> void:
	for i in _prongs.size():
		var rest := _prong_rest[i]
		var radial := Vector3(rest.origin.x, rest.origin.y, 0.0)
		if radial.length() < 0.0001:
			continue
		# Closing turns each prong's tip in toward the claw's axis (-Z).
		var axis := radial.normalized().cross(Vector3.FORWARD).normalized()
		_prongs[i].transform = Transform3D(Basis(axis, deg_to_rad(degrees)) * rest.basis, rest.origin)


## The cable from the chute: taut while the claw flies or reels, a little slack on the way home.
func _draw_cable(cam: Camera3D, muzzle: Vector3) -> void:
	if cam == null:
		_cable_mesh.clear_surfaces()
		return
	var end := global_position
	var sag := 0.08 if phase == Phase.BACK else 0.015
	var buzz := 0.012 if phase in [Phase.YANK, Phase.REEL] else 0.0
	var t := Time.get_ticks_msec() * 0.001
	for i in CABLE_POINTS + 1:
		var k := float(i) / CABLE_POINTS
		var p := muzzle.lerp(end, k)
		p += Vector3.DOWN * sag * sin(k * PI) * minf(1.0, muzzle.distance_to(end) / 6.0)
		p += Vector3.UP * buzz * sin(k * PI) * sin(t * 70.0 + k * 8.0)
		_points[i] = p
	var taut := 1.0 if phase in [Phase.YANK, Phase.REEL] else 0.0
	WeaponFx.begin_ribbons(_cable_mesh, WeaponFx.ribbon_material())
	WeaponFx.add_ribbon(_cable_mesh, _points, 0.05 + 0.03 * taut, Color(CABLE_GLOW, 0.22 + 0.2 * taut), cam.global_position)
	WeaponFx.add_ribbon(_cable_mesh, _points, 0.016, Color(CABLE, 0.95), cam.global_position)
	WeaponFx.end_ribbons(_cable_mesh)


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
