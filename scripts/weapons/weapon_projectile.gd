class_name WeaponProjectile
extends Node3D
## A physical shot: flies with gravity, bounces off scenery a set number of
## times, and detonates on a zombie, on its last bounce or when its fuse runs
## out. Damage (splash or direct) is dealt through the WeaponController so
## hit confirms, frozen bonuses and statuses work like any other shot.
## Trails a short glowing tail so its arc is easy to follow.

const MASK_WORLD := 1
const MASK_ENEMIES := 4
const TRAIL := 10

var weapon: WeaponData
var controller: WeaponController
var velocity := Vector3.ZERO
var _fuse := 0.0
var _bounces := 0
var _done := false
var _ball: MeshInstance3D
var _trail: MultiMeshInstance3D
var _history: Array[Vector3] = []
var _spin := Vector3.ZERO
var _exclude: Array[RID] = []

static var _ball_mesh: SphereMesh
static var _trail_mesh: SphereMesh
static var _band_mesh: TorusMesh
static var _mats := {}


## Launches a projectile under `parent`.
static func launch(parent: Node, from: Vector3, vel: Vector3, w: WeaponData, owner_controller: WeaponController) -> WeaponProjectile:
	var p := WeaponProjectile.new()
	p.weapon = w
	p.controller = owner_controller
	p.velocity = vel
	parent.add_child(p)
	p.global_position = from
	return p


func _ready() -> void:
	_fuse = weapon.projectile_fuse
	_bounces = weapon.projectile_bounces
	_spin = Vector3(randf_range(8, 14), randf_range(-4, 4), 0)
	if _ball_mesh == null:
		_ball_mesh = SphereMesh.new()
		_ball_mesh.radius = 1.0
		_ball_mesh.height = 2.0
		_ball_mesh.radial_segments = 16
		_ball_mesh.rings = 8
		_trail_mesh = SphereMesh.new()
		_trail_mesh.radius = 1.0
		_trail_mesh.height = 2.0
		_trail_mesh.radial_segments = 8
		_trail_mesh.rings = 4
		_band_mesh = TorusMesh.new()
		_band_mesh.inner_radius = 0.92
		_band_mesh.outer_radius = 1.12
		_band_mesh.rings = 16
		_band_mesh.ring_segments = 6
	_ball = MeshInstance3D.new()
	_ball.mesh = _ball_mesh
	_ball.material_override = _material(false)
	_ball.scale = Vector3.ONE * weapon.projectile_size
	_ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ball)
	var stripe := MeshInstance3D.new()
	stripe.mesh = _band_mesh
	stripe.material_override = _material(true)
	_ball.add_child(stripe)
	_trail = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _trail_mesh
	mm.instance_count = TRAIL
	_trail.multimesh = mm
	_trail.material_override = _material(true)
	_trail.top_level = true
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trail)


## Draws a resting projectile of `w` (ball, band and trail) under `parent` so
## its materials compile behind the level's fade-in (see FxWarmup). It never
## flies: it is marked done before its first physics frame.
static func warm_up(parent: Node, at: Vector3, w: WeaponData) -> void:
	var p := WeaponProjectile.new()
	p.weapon = w
	p._done = true
	parent.add_child(p)
	p.global_position = at
	p._update_trail()


func _material(glow: bool) -> StandardMaterial3D:
	var key := "%s|%s" % [weapon.tracer_color.to_html(), glow]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		if glow:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.albedo_color = Color(weapon.tracer_color.lerp(Color.WHITE, 0.2), 0.55)
		else:
			m.albedo_color = weapon.tracer_color.lerp(Color.WHITE, 0.3)
			m.emission_enabled = true
			m.emission = weapon.tracer_color
			m.emission_energy_multiplier = 2.2
			m.roughness = 0.25
		_mats[key] = m
	return _mats[key]


func _physics_process(delta: float) -> void:
	if _done:
		return
	_fuse -= delta
	if _fuse <= 0.0:
		_detonate(global_position, null)
		return
	velocity.y -= weapon.projectile_gravity * delta
	var from := global_position
	var to := from + velocity * delta
	var near := _zombie_near(to)
	if near:
		_detonate(to, near)
		return
	var query := PhysicsRayQueryParameters3D.create(from, to, MASK_WORLD | MASK_ENEMIES)
	if _exclude.is_empty() and is_instance_valid(controller) and is_instance_valid(controller.player):
		_exclude = [controller.player.get_rid()]
	query.exclude = _exclude
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = to
	else:
		var collider = hit["collider"]
		if collider is Zombie and not collider.is_dead():
			_detonate(hit["position"], collider)
			return
		if _bounces <= 0:
			_detonate(hit["position"] + hit["normal"] * 0.1, null)
			return
		_bounces -= 1
		var n: Vector3 = hit["normal"]
		velocity = velocity.bounce(n) * weapon.projectile_bounciness
		global_position = hit["position"] + n * 0.05
		Sfx.play_at(weapon.bounce_sound, global_position, -3.0, randf_range(0.95, 1.1))
		WeaponFx.burst(get_parent(), global_position, n, [weapon.tracer_color, Color.WHITE], 6, 2.5, 0.25, 0.04)
	_ball.rotation += _spin * delta
	_update_trail()


## Proximity fuse: a ball that skims past a zombie still goes off.
func _zombie_near(at: Vector3) -> Zombie:
	var reach := weapon.projectile_size + 0.5
	for node in get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z == null or z.is_dead():
			continue
		var base := z.global_position
		var top := 1.8 * z.data.body_scale
		if at.y < base.y - 0.1 or at.y > base.y + top:
			continue
		if Vector2(at.x - base.x, at.z - base.z).length() <= reach * z.data.body_scale:
			return z
	return null


func _update_trail() -> void:
	_history.push_front(global_position)
	if _history.size() > TRAIL:
		_history.pop_back()
	var mm := _trail.multimesh
	for i in TRAIL:
		var p: Vector3 = _history[mini(i, _history.size() - 1)]
		var s := weapon.projectile_size * (1.0 - float(i) / TRAIL) * 0.8
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), p))


func _detonate(at: Vector3, direct: Zombie) -> void:
	_done = true
	if is_instance_valid(controller):
		controller.projectile_detonated(weapon, at, direct, velocity.normalized())
	else:
		WeaponFx.explosion(get_parent(), at, weapon.tracer_color, maxf(1.0, weapon.splash_radius))
	queue_free()
