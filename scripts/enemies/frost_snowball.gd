class_name FrostSnowball
extends EnemyProjectile
## The Yeti's snowball: a big, slow, arcing EnemyProjectile that bursts into a
## puff of snow (instead of the usual colour pop) when it lands.

static var _flake_mesh: Mesh


## Lobs a snowball at `target_position` (see EnemyProjectile.launch).
static func lob(parent: Node, from: Vector3, target_position: Vector3, speed: float, dmg: float, size: float,
		arc: float, shooter: Node3D) -> FrostSnowball:
	var p := FrostSnowball.new()
	p.damage = dmg
	p.color = Color(0.82, 0.93, 1.0)
	p.radius = size
	p.source = shooter
	p.gravity = 18.0 * arc
	var to := target_position - from
	var flat := Vector3(to.x, 0.0, to.z)
	var t := maxf(0.4, flat.length() / speed)
	p.velocity = flat / t
	p.velocity.y = (to.y + 0.5 * p.gravity * t * t) / t
	parent.add_child(p)
	p.global_position = from
	return p


func _pop(at: Vector3) -> void:
	_snow_puff(get_parent(), at)
	Sfx.play_at(&"frost_snowball_hit", at, -2.0, randf_range(0.9, 1.1))
	queue_free()


static func _snow_puff(parent: Node, at: Vector3) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	if _flake_mesh == null:
		var box := BoxMesh.new()
		box.size = Vector3.ONE
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		box.material = m
		_flake_mesh = box
	var burst := FxBurst.new()
	burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(burst)
	var colors := [Color(0.95, 0.97, 1.0), Color(0.8, 0.88, 1.0), Color(0.7, 0.92, 1.0)]
	burst.setup(at, Vector3.UP, colors, 26, 5.0, 0.7, 0.16, 75.0, Vector3(0, -7.0, 0), _flake_mesh)
