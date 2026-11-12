class_name EnemyProjectile
extends Node3D
## A slow, visible enemy projectile (spit, thrown object, energy orb). It
## travels in a straight line or an arc, glows so it can be read and dodged,
## and damages the player on contact. Hits scenery and pops.
##
##   EnemyProjectile.launch(parent, from, target_position, speed, damage, color)

const PLAYER_RADIUS := 0.75

var velocity := Vector3.ZERO
var gravity := 0.0
var damage := 10.0
var radius := 0.25
var life := 6.0
var color := Color(0.6, 1.0, 0.3)
var source: Node3D
var _mesh: MeshInstance3D
var _trail_t := 0.0

static var _sphere: SphereMesh


## Fires at `target_position`. With `arc` > 0 the shot is lobbed (gravity) so
## it lands on the target after a flight time scaled by distance.
static func launch(parent: Node, from: Vector3, target_position: Vector3, speed: float, dmg: float,
		col := Color(0.6, 1.0, 0.3), arc := 0.0, size := 0.25, shooter: Node3D = null) -> EnemyProjectile:
	var p := EnemyProjectile.new()
	p.damage = dmg
	p.color = col
	p.radius = size
	p.source = shooter
	var to := target_position - from
	if arc > 0.0:
		p.gravity = 18.0 * arc
		var flat := Vector3(to.x, 0.0, to.z)
		var t := maxf(0.35, flat.length() / speed)
		p.velocity = flat / t
		p.velocity.y = (to.y + 0.5 * p.gravity * t * t) / t
	else:
		p.velocity = to.normalized() * speed
	parent.add_child(p)
	p.global_position = from
	return p


func _ready() -> void:
	if _sphere == null:
		_sphere = SphereMesh.new()
		_sphere.radius = 1.0
		_sphere.height = 2.0
		_sphere.radial_segments = 12
		_sphere.rings = 6
	_mesh = MeshInstance3D.new()
	_mesh.mesh = _sphere
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color.lerp(Color.WHITE, 0.25)
	_mesh.material_override = m
	_mesh.scale = Vector3.ONE * radius
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.2
	light.omni_range = 3.0
	add_child(light)


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	velocity.y -= gravity * delta
	var from := global_position
	var to := from + velocity * delta
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit := space.intersect_ray(q)
	var player := get_tree().get_first_node_in_group("player") as Player
	if player and player.alive:
		var chest := player.global_position + Vector3.UP * 1.0
		if Geometry3D.get_closest_point_to_segment(chest, from, to).distance_to(chest) <= PLAYER_RADIUS + radius:
			player.take_damage(damage, source.global_position if is_instance_valid(source) else from)
			_pop(to)
			return
	if not hit.is_empty():
		_pop(hit["position"])
		return
	global_position = to
	_trail_t -= delta
	if _trail_t <= 0.0:
		_trail_t = 0.05
		Fx.impact(get_parent(), global_position, -velocity.normalized(), color)
	_mesh.scale = Vector3.ONE * radius * (1.0 + 0.15 * sin(Time.get_ticks_msec() * 0.03))


func _pop(at: Vector3) -> void:
	Fx.hit_pop(get_parent(), at, velocity.normalized(), false)
	Sfx.play_at(&"hit_body", at, -6.0, 1.4)
	queue_free()
