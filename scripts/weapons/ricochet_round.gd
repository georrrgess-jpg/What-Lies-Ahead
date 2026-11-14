class_name RicochetRound
extends Node3D
## A bouncy gumball round (Gumball Drum Popper). It flies fast and nearly
## straight, ricochets off scenery up to WeaponData.projectile_bounces times
## and pops on the first zombie it touches: a plain ray-style hit through
## WeaponController.strike (headshots, falloff, confirms), no splash. Each
## ricochet adds RICOCHET_BONUS damage and bends the round toward a zombie
## close to its new path, so trick shots around corners land.

const MASK_WORLD := 1
const MASK_ENEMIES := 4
## Slight drop (m/s²), so long shots and floor bounces arc a little.
const GRAVITY := 3.0
## Damage bonus per ricochet before the hit (+25% after one, +50% after two).
const RICOCHET_BONUS := 0.25
## A ricochet bends toward a zombie inside this cone (degrees) and range (m).
const BEND_CONE := 30.0
const BEND_RANGE := 15.0
## Touching distance to a zombie's body (m), on top of the ball's size.
const REACH := 0.16
const TRAIL := 8
const TRAIL_LENGTH := 0.9
## The four gumball colours; each round picks one.
const COLORS: Array[Color] = [Color(1.0, 0.34, 0.68), Color(1.0, 0.84, 0.22), Color(0.28, 0.88, 1.0), Color(0.42, 0.95, 0.42)]

var weapon: WeaponData
var controller: WeaponController
var velocity := Vector3.ZERO
var _scale := 1.0
var _fuse := 0.0
var _bounces := 0
var _ricochets := 0
var _travelled := 0.0
var _color := Color.WHITE
var _ball: MeshInstance3D
var _trail: MultiMeshInstance3D
var _last := Vector3.ZERO
var _exclude: Array[RID] = []

static var _ball_mesh: SphereMesh
static var _trail_mesh: SphereMesh
static var _mats := {}


## Fires a round of `w` from `from` along `dir` (damage scale `scale`).
static func launch(owner_controller: WeaponController, from: Vector3, dir: Vector3, w: WeaponData, scale: float) -> void:
	var level := owner_controller.player.get_parent()
	if level == null:
		return
	var r := RicochetRound.new()
	r.weapon = w
	r.controller = owner_controller
	r.velocity = dir * w.projectile_speed
	r._scale = scale
	r._color = COLORS[randi() % COLORS.size()]
	r._exclude = [owner_controller.player.get_rid()]
	level.add_child(r)
	r.global_position = from
	r._last = from
	r._update_trail()


func _ready() -> void:
	_fuse = weapon.projectile_fuse
	_bounces = weapon.projectile_bounces
	if _ball_mesh == null:
		_ball_mesh = SphereMesh.new()
		_ball_mesh.radius = 1.0
		_ball_mesh.height = 2.0
		_ball_mesh.radial_segments = 12
		_ball_mesh.rings = 6
		_trail_mesh = SphereMesh.new()
		_trail_mesh.radius = 1.0
		_trail_mesh.height = 2.0
		_trail_mesh.radial_segments = 8
		_trail_mesh.rings = 4
	_ball = MeshInstance3D.new()
	_ball.mesh = _ball_mesh
	_ball.material_override = _material(_color, false)
	_ball.scale = Vector3.ONE * weapon.projectile_size
	_ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ball)
	_trail = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _trail_mesh
	mm.instance_count = TRAIL
	_trail.multimesh = mm
	_trail.material_override = _material(_color, true)
	_trail.top_level = true
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trail)


## The same two material kinds as WeaponProjectile (warmed up with it).
static func _material(color: Color, glow: bool) -> StandardMaterial3D:
	var key := "%s|%s" % [color.to_html(), glow]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		if glow:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.albedo_color = Color(color.lerp(Color.WHITE, 0.25), 0.5)
		else:
			m.albedo_color = color.lerp(Color.WHITE, 0.15)
			m.emission_enabled = true
			m.emission = color
			m.emission_energy_multiplier = 1.6
			m.roughness = 0.2
		_mats[key] = m
	return _mats[key]


func _physics_process(delta: float) -> void:
	_fuse -= delta
	if _fuse <= 0.0 or not is_instance_valid(controller):
		_pop(global_position, Vector3.UP)
		return
	velocity.y -= GRAVITY * delta
	var from := global_position
	var to := from + velocity * delta
	var near := _zombie_near(to)
	if near:
		_hit_zombie(near, to)
		return
	var query := PhysicsRayQueryParameters3D.create(from, to, MASK_WORLD | MASK_ENEMIES)
	query.exclude = _exclude
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		_travelled += from.distance_to(to)
		global_position = to
	else:
		var collider = hit["collider"]
		var at: Vector3 = hit["position"]
		_travelled += from.distance_to(at)
		if collider is Zombie and not collider.is_dead():
			_hit_zombie(collider, at)
			return
		var n: Vector3 = hit["normal"]
		if _bounces <= 0:
			ImpactMarks.shot(get_parent(), hit, velocity.normalized(), weapon)
			_pop(at + n * 0.05, n)
			return
		_ricochet(hit, at, n)
	_update_trail()


## Bounces off scenery and bends toward a zombie near the new path.
func _ricochet(hit: Dictionary, at: Vector3, n: Vector3) -> void:
	_bounces -= 1
	_ricochets += 1
	ImpactMarks.scuff(get_parent(), hit, velocity.normalized(), weapon)
	var speed := velocity.length() * weapon.projectile_bounciness
	var dir := velocity.bounce(n).normalized()
	global_position = at + n * 0.05
	var target := _bend_target(global_position, dir)
	if target != Vector3.INF:
		dir = (target - global_position).normalized()
	velocity = dir * speed
	Sfx.play_at(weapon.bounce_sound, global_position, -4.0, randf_range(0.95, 1.12))
	WeaponFx.burst(get_parent(), global_position, n, [_color, Color.WHITE], 6, 2.6, 0.22, 0.035)


## Chest of the zombie closest to `dir` inside the bend cone, in sight of
## `from` (Vector3.INF if none).
func _bend_target(from: Vector3, dir: Vector3) -> Vector3:
	var best := Vector3.INF
	var best_angle := deg_to_rad(BEND_CONE)
	var space := get_world_3d().direct_space_state
	for node in get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z == null or z.is_dead():
			continue
		var chest := z.global_position + Vector3.UP * 1.0 * z.data.body_scale
		var to := chest - from
		if to.length() > BEND_RANGE:
			continue
		var angle := dir.angle_to(to)
		if angle >= best_angle:
			continue
		var q := PhysicsRayQueryParameters3D.create(from, chest, MASK_WORLD)
		if space.intersect_ray(q).is_empty():
			best = chest
			best_angle = angle
	return best


## Proximity: a round that skims a zombie still hits it.
func _zombie_near(at: Vector3) -> Zombie:
	var reach := weapon.projectile_size + REACH
	for node in get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z == null or z.is_dead():
			continue
		var base := z.global_position
		if at.y < base.y or at.y > base.y + 1.85 * z.data.body_scale:
			continue
		if Vector2(at.x - base.x, at.z - base.z).length() <= (0.3 + reach) * z.data.body_scale:
			return z
	return null


func _hit_zombie(z: Zombie, at: Vector3) -> void:
	var dir := velocity.normalized()
	controller.strike(weapon, z, at, dir, _travelled, _scale * (1.0 + RICOCHET_BONUS * _ricochets))
	if _ricochets > 0:
		# A trick shot gets a brighter pop.
		WeaponFx.flash(get_parent(), at, _color, 0.45)
	_pop(at, -dir)


## The gumball pops: a candy burst and a soft pop.
func _pop(at: Vector3, normal: Vector3) -> void:
	WeaponFx.burst(get_parent(), at, normal, [_color, Color.WHITE, _color.lerp(Color.WHITE, 0.5)], 9, 3.2, 0.3, 0.04)
	Sfx.play_at(weapon.explosion_sound, at, -6.0, randf_range(0.94, 1.1))
	queue_free()


## A tapering streak over the last frame's flight (at most TRAIL_LENGTH).
func _update_trail() -> void:
	var tail := _last - global_position
	if tail.length() > TRAIL_LENGTH:
		tail = tail.normalized() * TRAIL_LENGTH
	_last = global_position
	var mm := _trail.multimesh
	for i in TRAIL:
		var k := float(i + 1) / TRAIL
		var s := weapon.projectile_size * (1.0 - k * 0.8) * 0.8
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), global_position + tail * k))
