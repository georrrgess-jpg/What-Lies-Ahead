class_name RingShot
extends Node3D
## A thrown ring (WeaponData.ricochet_count > 0, the Ring Toss). It is
## physical and visible the whole way, with travel time on every leg:
##
##   out    flies straight where it was aimed (projectile_speed), glancing off
##          scenery up to projectile_bounces times, out to max_range
##   hop    after striking a zombie it curves on to the nearest zombie it has
##          not struck yet within ricochet_range (in sight), up to
##          ricochet_count more, each strike ricochet_falloff weaker
##   back   then it flies home to the gun's muzzle and the viewmodel catches
##          it (WeaponView.weapon_event &"catch" / &"catch_ringer")
##
## Damage goes through WeaponController.ring_hit, so hit confirms, statuses
## and kills count like any shot. A headshot is a "ringer": it flashes gold,
## and with ringer_refund the ring comes home loaded (the round goes back in
## the magazine). The ring trails a ribbon so its path is easy to follow.

const MASK_WORLD := 1
const MASK_ENEMIES := 4
## Distance (m) at which the ring strikes a zombie it passes (or homes onto).
const REACH := 0.32
## A hop curves onto its target at this rate (1/s), and gives up after HOP_TIME.
const STEER := 16.0
const HOP_TIME := 0.9
const RETURN_SPEED_SCALE := 1.35
## The ring is caught this close to the muzzle, or after BACK_TIME regardless.
const CATCH_DISTANCE := 0.7
const BACK_TIME := 2.0
const TRAIL := 14
const RINGER_COLOR := Color(1.0, 0.85, 0.25)

enum Phase { OUT, HOP, BACK }

var weapon: WeaponData
var controller: WeaponController
var velocity := Vector3.ZERO
var phase := Phase.OUT
var ringer := false
var _speed := 1.0
var _travelled := 0.0
var _bounces := 0
var _strikes := 0
var _phase_time := 0.0
var _target: Zombie
var _struck: Array[RID] = []
var _exclude: Array[RID] = []
var _spin := 0.0
var _ring: MeshInstance3D
var _trail: MeshInstance3D
var _trail_mesh: ImmediateMesh
var _history := PackedVector3Array()

static var _ring_mesh: TorusMesh
static var _mats := {}


## Throws a ring from `from` with velocity `vel` under `parent`.
static func launch(parent: Node, from: Vector3, vel: Vector3, w: WeaponData, owner_controller: WeaponController) -> RingShot:
	var r := RingShot.new()
	r.weapon = w
	r.controller = owner_controller
	r.velocity = vel
	parent.add_child(r)
	r.global_position = from
	return r


func _ready() -> void:
	_speed = maxf(1.0, velocity.length())
	_bounces = weapon.projectile_bounces
	if _ring_mesh == null:
		_ring_mesh = TorusMesh.new()
		_ring_mesh.inner_radius = 0.72
		_ring_mesh.outer_radius = 1.0
		_ring_mesh.rings = 24
		_ring_mesh.ring_segments = 8
	_ring = MeshInstance3D.new()
	_ring.mesh = _ring_mesh
	_ring.material_override = _material(weapon.tracer_color, false)
	_ring.scale = Vector3.ONE * weapon.projectile_size
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	var halo := MeshInstance3D.new()
	halo.mesh = _ring_mesh
	halo.material_override = _material(weapon.tracer_color, true)
	halo.scale = Vector3(1.12, 1.6, 1.12)
	_ring.add_child(halo)
	_trail_mesh = ImmediateMesh.new()
	_trail = MeshInstance3D.new()
	_trail.mesh = _trail_mesh
	_trail.top_level = true
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trail)
	_trail.global_transform = Transform3D.IDENTITY


## Solid glowing ring (`glow` false) or its additive halo, one per colour.
static func _material(color: Color, glow: bool) -> StandardMaterial3D:
	var key := "%s|%s" % [color.to_html(), glow]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		if glow:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.albedo_color = Color(color.lerp(Color.WHITE, 0.2), 0.5)
		else:
			m.albedo_color = color.lerp(Color.WHITE, 0.35)
			m.emission_enabled = true
			m.emission = color
			m.emission_energy_multiplier = 2.4
			m.roughness = 0.25
		_mats[key] = m
	return _mats[key]


func _physics_process(delta: float) -> void:
	if not is_instance_valid(controller) or not is_instance_valid(controller.player):
		queue_free()
		return
	_phase_time += delta
	match phase:
		Phase.OUT:
			_fly_out(delta)
		Phase.HOP:
			_hop(delta)
		Phase.BACK:
			_fly_back(delta)


func _process(delta: float) -> void:
	_spin += delta * 26.0
	# Lies nearly flat like a thrown hoop, tipped into its flight, spinning.
	var dir := velocity.normalized() if velocity.length() > 0.1 else Vector3.FORWARD
	var side := dir.cross(Vector3.UP)
	var up := Vector3.UP.rotated(side.normalized(), 0.45) if side.length() > 0.01 else Vector3.UP
	_ring.global_basis = Basis(Quaternion(Vector3.UP, up)) * Basis(Vector3.UP, _spin)
	_ring.scale = Vector3.ONE * weapon.projectile_size
	_draw_trail()


# --- flight -------------------------------------------------------------------

func _fly_out(delta: float) -> void:
	var from := global_position
	var to := from + velocity * delta
	_travelled += velocity.length() * delta
	var near := _zombie_near(to)
	if near:
		_strike(near, to, from)
		return
	var hit := _ray(from, to)
	if hit.is_empty():
		global_position = to
	else:
		var collider = hit["collider"]
		if collider is Zombie and not collider.is_dead():
			_strike(collider, hit["position"], from)
			return
		if not _glance(hit):
			return
	if _travelled > weapon.max_range:
		_go_back()


## Off a wall: bounces while it has bounces left, otherwise heads home.
## Returns false when the ring turned for home.
func _glance(hit: Dictionary) -> bool:
	var n: Vector3 = hit["normal"]
	var at: Vector3 = hit["position"]
	WeaponFx.burst(get_parent(), at, n, [weapon.tracer_color, Color.WHITE], 7, 3.0, 0.25, 0.04)
	ImpactMarks.scuff(get_parent(), hit, velocity.normalized(), weapon)
	Sfx.play_at(weapon.bounce_sound, at, -2.0, randf_range(0.95, 1.1))
	global_position = at + n * 0.08
	if _bounces <= 0:
		_go_back()
		return false
	_bounces -= 1
	velocity = velocity.bounce(n)
	return true


func _hop(delta: float) -> void:
	if not is_instance_valid(_target) or _target.is_dead() or _phase_time > HOP_TIME:
		if not _next_target(global_position):
			_go_back()
		return
	var aim := _chest(_target)
	var want := (aim - global_position).normalized() * _speed
	velocity = (velocity + (want - velocity) * minf(1.0, STEER * delta)).normalized() * _speed
	var from := global_position
	var to := from + velocity * delta
	if to.distance_to(aim) <= REACH + 0.25 * _target.data.body_scale or _zombie_near(to) == _target:
		_strike(_target, to, from)
		return
	var hit := _ray(from, to)
	if not hit.is_empty() and not (hit["collider"] is Zombie):
		_glance(hit)
		_go_back()
		return
	global_position = to


func _fly_back(delta: float) -> void:
	var home := controller.player.view.muzzle_position()
	var to_home := home - global_position
	var dist := to_home.length()
	if dist <= CATCH_DISTANCE or _phase_time > BACK_TIME:
		_caught()
		return
	var speed := _speed * RETURN_SPEED_SCALE
	var want := to_home / dist * speed
	velocity = velocity + (want - velocity) * minf(1.0, 10.0 * delta)
	global_position += velocity * delta if velocity.length() * delta < dist else to_home


# --- strikes ------------------------------------------------------------------

func _strike(z: Zombie, point: Vector3, from: Vector3) -> void:
	_struck.append(z.get_rid())
	_exclude.append(z.get_rid())
	var dir := (point - from).normalized() if point.distance_to(from) > 0.001 else velocity.normalized()
	var head := z.is_head_hit(point, point - dir * 0.6)
	var dmg := weapon.damage * pow(weapon.ricochet_falloff, _strikes)
	if head:
		dmg *= weapon.headshot_multiplier
		ringer = true
		WeaponFx.flash(get_parent(), point, RINGER_COLOR, 0.9, 0.22)
		WeaponFx.burst(get_parent(), point, -dir, [RINGER_COLOR, Color.WHITE, weapon.tracer_color], 14, 4.0, 0.4, 0.05, 90.0)
	_strikes += 1
	global_position = point
	Sfx.play_at(weapon.ricochet_sound, point, -1.0, 1.0 + 0.08 * _strikes)
	controller.ring_hit(weapon, z, point, dir, dmg, head)
	if _strikes > weapon.ricochet_count or not _next_target(point):
		_go_back()


## Picks the nearest zombie not struck yet within ricochet_range (in sight of
## `from`). Returns false if there is none.
func _next_target(from: Vector3) -> bool:
	var best: Zombie = null
	var best_d := weapon.ricochet_range
	for node in get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z == null or z.is_dead() or _struck.has(z.get_rid()):
			continue
		var d := _chest(z).distance_to(from)
		if d < best_d and _clear(from, _chest(z)):
			best = z
			best_d = d
	if best == null:
		return false
	_target = best
	phase = Phase.HOP
	_phase_time = 0.0
	return true


func _go_back() -> void:
	phase = Phase.BACK
	_phase_time = 0.0
	_target = null


func _caught() -> void:
	var refund := ringer and weapon.ringer_refund
	if refund:
		controller.return_round(weapon)
	Sfx.play(weapon.catch_sound, -4.0 if refund else -7.0, 1.12 if refund else 1.0)
	controller.player.view.weapon_event(weapon, &"catch_ringer" if refund else &"catch")
	queue_free()


# --- helpers ------------------------------------------------------------------

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, MASK_WORLD | MASK_ENEMIES)
	if _exclude.is_empty():
		_exclude.append(controller.player.get_rid())
	query.exclude = _exclude
	return get_world_3d().direct_space_state.intersect_ray(query)


static func _chest(z: Zombie) -> Vector3:
	return z.global_position + Vector3.UP * 1.05 * z.data.body_scale


func _clear(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, MASK_WORLD)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## An unstruck zombie the ring passes close enough to strike.
func _zombie_near(at: Vector3) -> Zombie:
	for node in get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z == null or z.is_dead() or _struck.has(z.get_rid()):
			continue
		var base := z.global_position
		var s := z.data.body_scale
		if at.y < base.y - 0.1 or at.y > base.y + 1.9 * s:
			continue
		if Vector2(at.x - base.x, at.z - base.z).length() <= REACH + z.data.capsule_radius * s * 0.6:
			return z
	return null


func _draw_trail() -> void:
	if _history.is_empty():
		_history.resize(TRAIL)
		_history.fill(global_position)
	for i in range(TRAIL - 1, 0, -1):
		_history[i] = _history[i - 1]
	_history[0] = global_position
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var color := RINGER_COLOR if ringer else weapon.tracer_color
	WeaponFx.begin_ribbons(_trail_mesh, WeaponFx.ribbon_material())
	WeaponFx.add_ribbon(_trail_mesh, _history, weapon.projectile_size * 1.1, Color(color, 0.7), cam.global_position)
	WeaponFx.end_ribbons(_trail_mesh)
