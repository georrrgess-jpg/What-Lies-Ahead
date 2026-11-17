class_name JackPotBox
extends Node3D
## The Jack Pot's mine: a spring-loaded jack-in-the-box (art/models/jack_pot_box.glb).
##
## It is lobbed on the WeaponData's launch velocity (gravity and loft, so the
## aim arc preview shows where it lands), tumbling. On the floor it hops
## upright, then winds itself up for ARM_TIME (its crank turns, a music-box
## tune plays, its lid lamp blinks) and arms: a faint ring on the floor shows
## its reach. The first zombie that comes within TRIGGER_RADIUS of an armed
## box sets it off: the lid bursts open and a clown on a spring pops out and
## throws a boxing-glove punch at it. A box that strikes a zombie in flight
## pops at once on that zombie, and a wall bounces it.
##
## The punch (PUNCH_AT after the lid opens) hits its target for the weapon's
## damage and knocks it up into the air (Launch: it cannot move or attack
## while airborne, then it lands seeing stars, Dazzle), and the burst hits
## every other zombie within splash_radius for less (splash_edge_scale at the
## rim), bouncing the closest. Heavies (HEAVY_MASS and up) only hop and
## stagger; bosses and the heaviest alphas (BOSS_MASS) are only nudged: they
## take BOSS_SCALE of the damage and are slowed, never launched or staggered.
##
## A player has at most MAX_BOXES boxes out: launching one more pops the
## oldest at once (on whatever is near it). An armed box nobody walks into
## pops by itself after LIFETIME. tools/balance_report.py reads these constants.

const MASK_WORLD := 1
const MASK_ENEMIES := 4
const MODEL: PackedScene = preload("res://art/models/jack_pot_box.glb")
const MAX_BOXES := 3
## Zombies this close (m, flat) to an armed box set it off.
const TRIGGER_RADIUS := 2.5
const REACH_UP := 2.0
const SETTLE_TIME := 0.24
const ARM_TIME := 0.8
const LIFETIME := 40.0
const FLIGHT_MAX := 3.0
const BOUNCE_KEEP := 0.35
const SCAN_INTERVAL := 0.05
## Seconds from the lid bursting open to the glove landing, and the whole pop.
const PUNCH_AT := 0.07
const POP_TIME := 1.5
const SHRINK_TIME := 0.25
## How high (m) the punch knocks a 1-mass zombie, and the share of that for
## the others the burst catches within LAUNCH_SPLASH metres.
const LAUNCH_HEIGHT := 0.9
const LAUNCH_SPLASH := 1.5
const SPLASH_LIFT := 0.5
const HEAVY_MASS := 2.5
const HEAVY_HOP := 0.16
const BOSS_MASS := 5.0
const BOSS_SCALE := 0.9
const BOSS_PUSH := 1.5
## Seconds of stars (Dazzle) after the punch (scaled down by weight there).
const STUN := 1.4
## The spring at full stretch (m above the box floor) and the glove's reach.
const SPRING_UP := 0.8
## The clown (and its glove) is drawn this much bigger than built, a proper
## jack-in-the-box head on its spring.
const CLOWN_SCALE := 1.5
const REACH_MIN := 0.25
const REACH_MAX := 1.6
const BOX_SIZE := 0.34
## The box model is drawn at this scale (it is built at BOX_SIZE).
const MODEL_SCALE := 0.9
const FLY_SPIN := 9.0
const LAND_SOUND := &"jp_land"
const TUNE_SOUND := &"jp_tune"
const ARMED_SOUND := &"jp_armed"
const BOING_SOUND := &"jp_boing"
const PUNCH_SOUND := &"jp_punch"
const POOF_SOUND := &"jp_poof"
const CONFETTI: Array[Color] = [Color(1.0, 0.2, 0.33), Color(0.2, 0.44, 1.0), Color(1.0, 0.82, 0.23), Color(0.24, 0.86, 0.52), Color(1.0, 0.42, 0.84)]
const RING_COLOR := Color(1.0, 0.42, 0.84)

enum Phase { FLY, SETTLE, WIND, ARMED, POP }

var weapon: WeaponData
var controller: WeaponController
var velocity := Vector3.ZERO
var phase := Phase.FLY
var _t := 0.0
var _scan := 0.0
var _exclude: Array[RID] = []
var _model: Node3D
var _parts := {}
var _rest := {}
var _land_from := Quaternion.IDENTITY
var _yaw := 0.0
var _target: Zombie
var _reach := 1.0
var _punched := false
var _ring: MeshInstance3D

static var _live: Array[JackPotBox] = []
static var _ring_mesh: TorusMesh
static var _ring_mat: StandardMaterial3D


## A zombie knocked into the air by the punch: it hangs on the spring's
## arc (the model rises and tips back, the body is held), drifting with
## the knockback, and cannot move or attack until it lands.
class Launch extends EnemyBehaviour:
	var height := 0.9
	var air := 0.6
	var t := 0.0
	var model: Node3D
	var done := false

	func on_physics(z: Zombie, delta: float) -> bool:
		if done:
			return false
		t += delta
		var u := clampf(t / air, 0.0, 1.0)
		model.position.y = height * 4.0 * u * (1.0 - u)
		model.rotation.x = -0.45 * sin(PI * u) * minf(1.0, height)
		z.move_with(Vector3.ZERO)
		if u >= 1.0:
			_land(z)
		return true

	func on_death(_z: Zombie) -> void:
		if done or model == null:
			return
		done = true
		var tw := model.create_tween().set_parallel(true)
		tw.tween_property(model, "position:y", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(model, "rotation:x", 0.0, 0.22)

	## Again from the ground (a second box caught it mid-air).
	func relaunch(h: float) -> void:
		height = maxf(h, model.position.y + h * 0.5)
		air = JackPotBox.air_time(height)
		t = 0.0

	func _land(z: Zombie) -> void:
		done = true
		model.position.y = 0.0
		model.rotation.x = 0.0
		_drop.call_deferred(z)
		WeaponFx.burst(z.get_parent(), z.global_position + Vector3.UP * 0.1, Vector3.UP, [Color(0.85, 0.8, 0.75), Color(1.0, 1.0, 1.0)], 8, 2.5, 0.35, 0.05, 80.0, Vector3(0, -4.0, 0))

	func _drop(z: Zombie) -> void:
		if is_instance_valid(z):
			z.behaviours.erase(self)


## Throws a box of `w` from `from` with launch velocity `vel`. A player
## already at MAX_BOXES pops their oldest first.
static func launch(owner_controller: WeaponController, from: Vector3, vel: Vector3, w: WeaponData) -> void:
	var level := owner_controller.player.get_parent()
	if level == null:
		return
	var mine := live(owner_controller)
	if mine.size() >= MAX_BOXES:
		mine[0].pop_now()
	var b := JackPotBox.new()
	b.weapon = w
	b.controller = owner_controller
	b.velocity = vel
	b._exclude = [owner_controller.player.get_rid()]
	level.add_child(b)
	b.global_position = from
	b._yaw = atan2(-vel.x, -vel.z) + PI
	_live.append(b)


## `owner_controller`'s boxes still waiting to pop, oldest first.
static func live(owner_controller: WeaponController) -> Array[JackPotBox]:
	var out: Array[JackPotBox] = []
	for b in _live.duplicate():
		if not is_instance_valid(b) or b.phase == Phase.POP:
			_live.erase(b)
		elif b.controller == owner_controller:
			out.append(b)
	return out


## Seconds a zombie knocked `height` metres up stays in the air.
static func air_time(height: float) -> float:
	return 2.0 * sqrt(2.0 * maxf(0.05, height) / Zombie.GRAVITY) + 0.12


func _ready() -> void:
	_model = MODEL.instantiate()
	add_child(_model)
	for part in ["Box", "Lid", "Lamp", "Crank", "Spring", "Clown", "Arm", "Glove"]:
		var node := _model.find_child(part, true, false) as Node3D
		if node:
			_parts[part] = node
			_rest[part] = node.transform
	for part in ["Spring", "Clown"]:
		_show(part, false)
	for node in _model.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_model.scale = Vector3.ONE * MODEL_SCALE


func _exit_tree() -> void:
	_live.erase(self)


func _physics_process(delta: float) -> void:
	_t += delta
	match phase:
		Phase.FLY:
			_fly(delta)
		Phase.ARMED:
			_scan -= delta
			if _scan <= 0.0:
				_scan = SCAN_INTERVAL
				var z := _nearest(TRIGGER_RADIUS)
				if z:
					_pop(z)
			if phase == Phase.ARMED and _t >= LIFETIME:
				pop_now()
		Phase.POP:
			if not _punched and _t >= PUNCH_AT:
				_punch()


func _process(delta: float) -> void:
	match phase:
		Phase.FLY:
			_model.rotate_object_local(Vector3.RIGHT, FLY_SPIN * delta)
		Phase.SETTLE:
			_pose_settle()
		Phase.WIND:
			_pose_wind()
		Phase.ARMED:
			_pose_armed()
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
	var query := PhysicsRayQueryParameters3D.create(from, to, MASK_WORLD | MASK_ENEMIES)
	query.exclude = _exclude
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = to
		var near := _nearest(0.6, to)
		if near and absf(to.y - near.global_position.y - 0.9 * near.data.body_scale) < 1.0 * near.data.body_scale:
			_direct(near)
		return
	var z := hit["collider"] as Zombie
	if z and not z.is_dead():
		_direct(z)
		return
	var normal: Vector3 = hit["normal"]
	if normal.y >= 0.6:
		_land_at(Vector3(hit["position"]))
		return
	# A wall: bounce off it and keep falling.
	global_position = Vector3(hit["position"]) + normal * 0.08
	velocity = velocity.bounce(normal) * BOUNCE_KEEP
	Sfx.play_at(LAND_SOUND, global_position, -6.0, 1.3, 10.0)


## Struck a zombie in flight: it drops at its feet and pops on it at once.
func _direct(z: Zombie) -> void:
	_settle_at(z.global_position + (global_position - z.global_position).normalized().slide(Vector3.UP) * 0.3, false)
	_pop(z)


## Lands on the floor below `at`, then hops upright and winds up.
func _land_at(at: Vector3) -> void:
	_settle_at(at, true)
	phase = Phase.SETTLE
	_t = 0.0
	Sfx.play_at(LAND_SOUND, global_position, -2.0, randf_range(0.95, 1.05), 10.0)
	WeaponFx.burst(get_parent(), global_position + Vector3.UP * 0.05, Vector3.UP, CONFETTI, 6, 2.0, 0.3, 0.04, 70.0, Vector3(0, -5.0, 0))


func _settle_at(at: Vector3, keep_tumble: bool) -> void:
	var ground := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.4, at + Vector3.DOWN * 4.0, MASK_WORLD))
	global_position = Vector3(ground["position"]) + Vector3.UP * 0.02 if not ground.is_empty() else at
	_land_from = _model.quaternion if keep_tumble else Quaternion.IDENTITY
	rotation = Vector3(0.0, _yaw, 0.0)
	_model.quaternion = _land_from


# --- arming ----------------------------------------------------------------------

## The hop upright: the tumble rights itself on a springy arc with a squash.
func _pose_settle() -> void:
	var u := clampf(_t / SETTLE_TIME, 0.0, 1.0)
	_model.quaternion = _land_from.slerp(Quaternion.IDENTITY, _ease_out_back(u))
	_model.position.y = 0.16 * sin(PI * u)
	var squash := 0.18 * sin(PI * clampf((u - 0.75) / 0.25, 0.0, 1.0))
	_model.scale = Vector3(1.0 + squash, 1.0 - squash, 1.0 + squash) * MODEL_SCALE
	if u >= 1.0:
		phase = Phase.WIND
		_t = 0.0
		Sfx.play_at(TUNE_SOUND, global_position + Vector3.UP * 0.3, -4.0, 1.0, 10.0)


## Winding up: the crank turns two turns, the lamp blinks, the box quivers.
func _pose_wind() -> void:
	var u := clampf(_t / ARM_TIME, 0.0, 1.0)
	_model.position.y = 0.0
	_model.quaternion = Quaternion.IDENTITY
	_model.scale = Vector3.ONE * MODEL_SCALE
	_turn_crank(TAU * 2.0 * _smooth(u))
	_show("Lamp", fmod(_t, 0.2) < 0.1)
	var quiver := 0.03 * u * sin(_t * 70.0)
	_model.rotation = Vector3(quiver, 0.0, quiver * 0.6)
	if u >= 1.0:
		_arm()


func _arm() -> void:
	phase = Phase.ARMED
	_t = 0.0
	_model.rotation = Vector3.ZERO
	_show("Lamp", true)
	Sfx.play_at(ARMED_SOUND, global_position + Vector3.UP * 0.3, -5.0, 1.0, 9.0)
	_ring = MeshInstance3D.new()
	_ring.mesh = _ring_torus()
	_ring.material_override = _ring_material()
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_ring.position.y = 0.04


## Armed: the lamp pulses, the ring breathes, and now and then the lid lifts
## a crack as if something inside cannot wait.
func _pose_armed() -> void:
	var lamp := _parts.get("Lamp") as Node3D
	if lamp:
		lamp.scale = Vector3.ONE * (1.0 + 0.18 * pow(maxf(0.0, sin(_t * 5.0)), 4.0))
	if _ring:
		var grow := _smooth(clampf(_t / 0.3, 0.0, 1.0))
		_ring.scale = Vector3(TRIGGER_RADIUS, 1.0, TRIGGER_RADIUS) * lerpf(0.3, 1.0 + 0.02 * sin(_t * 3.0), grow)
	var peek := fmod(_t + 0.6, 2.4)
	_set_lid(14.0 * sin(PI * clampf(peek / 0.3, 0.0, 1.0)))


# --- the pop ---------------------------------------------------------------------

## Pops now on whatever is nearest within the splash (the oldest box giving
## way to a new one, or one left too long).
func pop_now() -> void:
	if phase == Phase.POP:
		return
	if phase == Phase.FLY:
		_settle_at(global_position, false)
	_pop(_nearest(weapon.splash_radius))


func _pop(target: Zombie) -> void:
	phase = Phase.POP
	_t = 0.0
	_live.erase(self)
	_target = target
	_model.quaternion = Quaternion.IDENTITY
	_model.position = Vector3.ZERO
	_model.scale = Vector3.ONE * MODEL_SCALE
	_reach = REACH_MIN
	var clown := _parts.get("Clown") as Node3D
	if target and clown:
		var to := target.global_position - global_position
		var local := global_transform.basis.inverse() * to
		var face := atan2(-local.x, -local.z)
		clown.transform = _rest["Clown"] * Transform3D(Basis(Vector3.UP, face), Vector3.ZERO)
		_rest["ClownAim"] = clown.transform
		_reach = clampf((Vector2(to.x, to.z).length() / MODEL_SCALE - 0.6) / CLOWN_SCALE, REACH_MIN, REACH_MAX)
	else:
		_rest["ClownAim"] = _rest.get("Clown", Transform3D.IDENTITY)
	_show("Spring", true)
	_show("Clown", true)
	if _ring:
		_ring.queue_free()
		_ring = null
	var top := global_position + Vector3.UP * 0.5
	Sfx.play_at(BOING_SOUND, top, 1.0, randf_range(0.95, 1.06), 14.0)
	WeaponFx.flash(get_parent(), top, CONFETTI[2], 1.0, 0.18)
	WeaponFx.burst(get_parent(), top, Vector3.UP, CONFETTI, 34, 6.5, 1.0, 0.07, 55.0, Vector3(0, -6.0, 0))
	Fx.ticket_popup(get_parent(), top + Vector3.UP * 0.9, 0, "BOING!", CONFETTI[2])


## The glove lands: the target is punched up, the burst hits the rest.
func _punch() -> void:
	_punched = true
	var centre := global_position + Vector3.UP * 0.6
	WeaponFx.shockwave(get_parent(), global_position + Vector3.UP * 0.1, RING_COLOR, weapon.splash_radius)
	if is_instance_valid(_target) and not _target.is_dead():
		var chest := _target.global_position + Vector3.UP * 1.1 * _target.data.body_scale
		Sfx.play_at(PUNCH_SOUND, chest, 0.0, randf_range(0.94, 1.06), 12.0)
		WeaponFx.burst(get_parent(), chest, (chest - centre).normalized(), CONFETTI, 12, 4.0, 0.45, 0.05, 50.0, Vector3(0, -6.0, 0))
		_hit(_target, weapon.damage, LAUNCH_HEIGHT)
	if not is_instance_valid(controller):
		return
	for node in get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z == null or z == _target or z.is_dead():
			continue
		var flat := Vector2(z.global_position.x - global_position.x, z.global_position.z - global_position.z).length()
		if flat > weapon.splash_radius or absf(z.global_position.y - global_position.y) > REACH_UP:
			continue
		var k := 1.0 - flat / maxf(0.1, weapon.splash_radius)
		var lift := LAUNCH_HEIGHT * SPLASH_LIFT if flat <= LAUNCH_SPLASH else 0.0
		_hit(z, weapon.damage * lerpf(weapon.splash_edge_scale, 1.0, k), lift)


## One zombie caught by the pop: damage and a push away from the box, then
## up it goes (a kill flies too); heavies hop, bosses are only nudged.
func _hit(z: Zombie, dmg: float, lift: float) -> void:
	if not is_instance_valid(controller):
		return
	var boss := z.rank == Zombie.RANK_BOSS or z.data.mass >= BOSS_MASS
	var heavy := z.data.mass >= HEAVY_MASS
	var away := z.global_position - global_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.05 else -global_transform.basis.z
	var chest := z.global_position + Vector3.UP * 1.1 * z.data.body_scale
	var push := BOSS_PUSH if boss else weapon.splash_push
	var killed := controller.melee_hit(weapon, z, chest - away * 0.3, away, dmg * (BOSS_SCALE if boss else 1.0), push)
	if boss:
		if not killed:
			Dazzle.of(z).apply(STUN * 0.4)
		return
	var height := (HEAVY_HOP if heavy else lift / sqrt(maxf(0.6, z.data.mass))) if lift > 0.0 else 0.0
	if killed:
		if height > 0.0:
			_corpse_pop(z, height)
		return
	if lift > 0.0 or heavy:
		Dazzle.of(z).apply(STUN)
	if height > 0.0:
		_launch_zombie(z, height)


static func _launch_zombie(z: Zombie, height: float) -> void:
	for b in z.behaviours:
		if b is Launch and not (b as Launch).done:
			(b as Launch).relaunch(height)
			return
	var l := Launch.new()
	l.model = z.model_root
	l.height = height
	l.air = air_time(height)
	z.behaviours.append(l)


## A zombie the punch finished flies up while it falls.
static func _corpse_pop(z: Zombie, height: float) -> void:
	var model := z.model_root
	var air := air_time(height * 1.3)
	var tw := z.create_tween()
	tw.tween_method(func(u: float):
		if is_instance_valid(model):
			model.position.y = height * 1.3 * 4.0 * u * (1.0 - u)
			model.rotation.x = -0.6 * sin(PI * u), 0.0, 1.0, air)


## The pop: the lid bursts back, the spring shoots up and overshoots, the
## glove jabs out to the target and springs home, the clown sways on its
## spring, then the box shrinks away in a puff of confetti.
func _pose_pop() -> void:
	var t := _t
	_set_lid(125.0 * _spring(t, 9.0, 16.0))
	var h := SPRING_UP * _spring(t, 6.5, 19.0)
	var sway := 0.32 * exp(-2.4 * t) * sin(t * 11.0) * _smooth(clampf(t / 0.12, 0.0, 1.0))
	var spring := _parts.get("Spring") as Node3D
	var tilt := Basis(Vector3.RIGHT, sway) * Basis(Vector3.BACK, sway * 0.6)
	if spring:
		var rest: Transform3D = _rest["Spring"]
		spring.transform = Transform3D(tilt * rest.basis.scaled(Vector3(1.0, maxf(0.05, h / 0.211), 1.0)), rest.origin)
	var clown := _parts.get("Clown") as Node3D
	if clown:
		var aim: Transform3D = _rest["ClownAim"]
		var base: Vector3 = _rest["Spring"].origin
		clown.transform = Transform3D((tilt * aim.basis).scaled_local(Vector3.ONE * CLOWN_SCALE), base + tilt * Vector3.UP * (h + 0.005))
	_pose_glove(t)
	var shrink := clampf((t - (POP_TIME - SHRINK_TIME)) / SHRINK_TIME, 0.0, 1.0)
	if shrink > 0.0:
		_model.scale = Vector3.ONE * MODEL_SCALE * (1.0 - _ease_in_back(shrink))
	if t >= POP_TIME:
		Sfx.play_at(POOF_SOUND, global_position + Vector3.UP * 0.3, -6.0, randf_range(0.95, 1.05), 9.0)
		WeaponFx.burst(get_parent(), global_position + Vector3.UP * 0.3, Vector3.UP, CONFETTI, 14, 2.5, 0.6, 0.05, 90.0, Vector3(0, -3.0, 0))
		queue_free()


## The jab: out fast to the target, a beat there, back home on a wobble.
func _pose_glove(t: float) -> void:
	var out := _smooth(clampf((t - 0.02) / (PUNCH_AT - 0.02), 0.0, 1.0))
	var back := clampf((t - 0.16) / 0.3, 0.0, 1.0)
	var ext := _reach * out * (1.0 - back) + 0.12 * sin(back * PI * 3.0) * (1.0 - back) * float(back > 0.0)
	var arm := _parts.get("Arm") as Node3D
	var arm_len := 0.3 * BOX_SIZE
	if arm:
		var rest: Transform3D = _rest["Arm"]
		arm.transform = Transform3D(rest.basis.scaled(Vector3(1.0, 1.0, (arm_len + ext) / arm_len)), rest.origin)
	var glove := _parts.get("Glove") as Node3D
	if glove:
		var rest_g: Transform3D = _rest["Glove"]
		var punch := 1.0 + 0.35 * sin(PI * out) * (1.0 - back)
		glove.transform = Transform3D(rest_g.basis.scaled(Vector3.ONE * punch), rest_g.origin + Vector3.FORWARD * ext)


# --- helpers ---------------------------------------------------------------------

func _nearest(radius: float, from := Vector3.INF) -> Zombie:
	var at := global_position if from == Vector3.INF else from
	var best: Zombie = null
	var best_d := radius
	for node in get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z == null or z.is_dead():
			continue
		var p := z.global_position
		if absf(p.y - at.y) > REACH_UP and from == Vector3.INF:
			continue
		var d := Vector2(p.x - at.x, p.z - at.z).length()
		if d <= best_d:
			best = z
			best_d = d
	return best


func _turn_crank(angle: float) -> void:
	var crank := _parts.get("Crank") as Node3D
	if crank:
		crank.transform = _rest["Crank"] * Transform3D(Basis(Vector3.RIGHT, angle), Vector3.ZERO)


func _set_lid(degrees: float) -> void:
	var lid := _parts.get("Lid") as Node3D
	if lid:
		lid.transform = _rest["Lid"] * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(degrees)), Vector3.ZERO)


func _show(part: String, on: bool) -> void:
	var node := _parts.get(part) as Node3D
	if node:
		node.visible = on


## A damped spring released at t = 0 from 0 toward 1 (overshoots, settles).
static func _spring(t: float, damping: float, rate: float) -> float:
	return 1.0 - exp(-damping * t) * cos(rate * t)


## Smootherstep (zero speed and acceleration at both ends).
static func _smooth(u: float) -> float:
	return u * u * u * (u * (u * 6.0 - 15.0) + 10.0)


static func _ease_out_back(u: float) -> float:
	var c := 1.70158
	return 1.0 + (c + 1.0) * pow(u - 1.0, 3.0) + c * pow(u - 1.0, 2.0)


static func _ease_in_back(u: float) -> float:
	var c := 1.70158
	return (c + 1.0) * u * u * u - c * u * u


static func _ring_torus() -> TorusMesh:
	if _ring_mesh == null:
		_ring_mesh = TorusMesh.new()
		_ring_mesh.inner_radius = 0.97
		_ring_mesh.outer_radius = 1.0
		_ring_mesh.rings = 48
		_ring_mesh.ring_segments = 4
	return _ring_mesh


static func _ring_material() -> StandardMaterial3D:
	if _ring_mat == null:
		_ring_mat = StandardMaterial3D.new()
		_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_ring_mat.albedo_color = Color(RING_COLOR, 0.45)
	return _ring_mat
