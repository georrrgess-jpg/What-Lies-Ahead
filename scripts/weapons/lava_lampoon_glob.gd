class_name LavaLampoonGlob
extends Node3D
## A molten glob of the Lava Lampoon. It flies fast with a slight drop and a
## wobble, strikes the first zombie it touches like a ray shot
## (WeaponController.strike: headshots, falloff, confirms) and splats: a lava
## puddle (LavaPuddle) drops on the floor under where it burst. A glob that
## hits scenery splats there (on the floor below when it hit a wall).

const MASK_WORLD := 1
const MASK_ENEMIES := 4
## Drop (m/s²): long shots arc a little.
const GRAVITY := 4.0
## Touching distance to a zombie's body (m), on top of the glob's size.
const REACH := 0.12
## A wall splat finds the floor within this drop (m).
const FLOOR_DROP := 2.6
const TRAIL := 6
const TRAIL_LENGTH := 0.7
const CORE := Color(1.0, 0.86, 0.3)
const HOT := Color(1.0, 0.42, 0.1)
const SPLAT_COLORS := [Color(1.0, 0.86, 0.3), Color(1.0, 0.5, 0.12), Color(1.0, 0.2, 0.45), Color(1.0, 0.95, 0.75)]
const SPLAT_SOUND := &"weap_lava_splat"

static var _ball_mesh: SphereMesh
static var _core_mat: StandardMaterial3D
static var _trail_mat: StandardMaterial3D

var weapon: WeaponData
var controller: WeaponController
var velocity := Vector3.ZERO
var _scale := 1.0
var _fuse := 0.0
var _travelled := 0.0
var _age := 0.0
var _ball: MeshInstance3D
var _trail: MultiMeshInstance3D
var _last := Vector3.ZERO
var _exclude: Array[RID] = []


## Fires a glob of `w` from `from` along `dir` (damage scale `scale`).
static func launch(owner_controller: WeaponController, from: Vector3, dir: Vector3, w: WeaponData, scale: float) -> void:
	var level := owner_controller.player.get_parent()
	if level == null:
		return
	var g := LavaLampoonGlob.new()
	g.weapon = w
	g.controller = owner_controller
	g.velocity = dir * w.projectile_speed
	g._scale = scale
	g._exclude = [owner_controller.player.get_rid()]
	level.add_child(g)
	g.global_position = from
	g._last = from


func _ready() -> void:
	_fuse = weapon.projectile_fuse
	if _ball_mesh == null:
		_ball_mesh = SphereMesh.new()
		_ball_mesh.radius = 1.0
		_ball_mesh.height = 2.0
		_ball_mesh.radial_segments = 10
		_ball_mesh.rings = 5
		_core_mat = StandardMaterial3D.new()
		_core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_core_mat.albedo_color = CORE.lerp(Color.WHITE, 0.2)
		_trail_mat = StandardMaterial3D.new()
		_trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_trail_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_trail_mat.albedo_color = Color(HOT, 0.7)
	_ball = MeshInstance3D.new()
	_ball.mesh = _ball_mesh
	_ball.material_override = _core_mat
	_ball.scale = Vector3.ONE * weapon.projectile_size
	_ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ball)
	_trail = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _ball_mesh
	mm.instance_count = TRAIL
	_trail.multimesh = mm
	_trail.material_override = _trail_mat
	_trail.top_level = true
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trail)
	_update_trail()


func _physics_process(delta: float) -> void:
	_fuse -= delta
	_age += delta
	if _fuse <= 0.0 or not is_instance_valid(controller):
		queue_free()
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
		# The glob wobbles as it flies, stretched along its path.
		var w := sin(_age * 46.0) * 0.18
		_ball.scale = Vector3(1.0 + w, 1.0 - w, 1.0 + w * 0.5) * weapon.projectile_size
		_update_trail()
		return
	var at: Vector3 = hit["position"]
	_travelled += from.distance_to(at)
	var collider = hit["collider"]
	if collider is Zombie and not collider.is_dead():
		_hit_zombie(collider, at)
		return
	ImpactMarks.shot(get_parent(), hit, velocity.normalized(), weapon)
	_splat(at, hit["normal"], at)


## Proximity: a glob that skims a zombie still hits it.
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
	var feet := z.global_position
	controller.strike(weapon, z, at, dir, _travelled, _scale)
	_splat(at, -dir, feet + Vector3.UP * 0.4)


## The glob bursts at `at` and drops a puddle on the floor under `floor_from`.
func _splat(at: Vector3, normal: Vector3, floor_from: Vector3) -> void:
	var level := get_parent()
	WeaponFx.burst(level, at, normal, SPLAT_COLORS, 7, 3.0, 0.35, 0.04, 70.0)
	Sfx.play_at(SPLAT_SOUND, at, -7.0, randf_range(0.9, 1.1))
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(floor_from + Vector3.UP * 0.2, floor_from + Vector3.DOWN * FLOOR_DROP, MASK_WORLD)
	var ground := space.intersect_ray(q)
	if not ground.is_empty() and Vector3(ground["normal"]).y > 0.6:
		LavaPuddle.spawn(controller, Vector3(ground["position"]), weapon)
	queue_free()


## A tapering streak of hot droplets over the last frame's flight.
func _update_trail() -> void:
	var tail := _last - global_position
	if tail.length() > TRAIL_LENGTH:
		tail = tail.normalized() * TRAIL_LENGTH
	_last = global_position
	var mm := _trail.multimesh
	for i in TRAIL:
		var k := float(i + 1) / TRAIL
		var s := weapon.projectile_size * (1.0 - k * 0.75) * 1.1
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), global_position + tail * k))
