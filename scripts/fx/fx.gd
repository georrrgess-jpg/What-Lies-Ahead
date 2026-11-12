class_name Fx
extends RefCounted
## Tiny effect spawners. Everything is short-lived and non-gory:
## energy tracers, spark puffs and confetti pops.

static var _tracer_mesh: BoxMesh
static var _spark_mesh: Mesh
static var _materials := {}


static func _unshaded(color: Color, energy := 1.0) -> StandardMaterial3D:
	var key := "%s|%.2f" % [color.to_html(), energy]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color.r * energy, color.g * energy, color.b * energy, 1.0)
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials[key] = m
	return m


## A short bright streak that travels from the muzzle to the hit point.
static func tracer(parent: Node, from: Vector3, to: Vector3, color: Color, width: float) -> void:
	if parent == null or from.distance_to(to) < 0.5:
		return
	if _tracer_mesh == null:
		_tracer_mesh = BoxMesh.new()
		_tracer_mesh.size = Vector3(1, 1, 1)
	var t := Tracer.new()
	t.mesh = _tracer_mesh
	t.material_override = _unshaded(color.lerp(Color.WHITE, 0.35), 1.6)
	t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(t)
	t.launch(from, to, width)


## Sparks where a shot hits scenery.
static func impact(parent: Node, position: Vector3, normal: Vector3, color: Color) -> void:
	_burst(parent, position, normal, [color, Color.WHITE], 6, 3.0, 0.28, 0.05)


## Colourful pop when a shot lands on a zombie.
static func hit_pop(parent: Node, position: Vector3, direction: Vector3, headshot: bool) -> void:
	var colors := [Color(1.0, 0.35, 0.75), Color(0.3, 0.95, 1.0), Color(1.0, 0.85, 0.25)]
	_burst(parent, position, -direction, colors, 12 if headshot else 7, 4.5, 0.35, 0.07)


## Confetti burst when a zombie is defeated.
static func confetti(parent: Node, position: Vector3) -> void:
	var colors := [Color(1.0, 0.35, 0.75), Color(0.3, 0.95, 1.0), Color(1.0, 0.85, 0.25), Color(0.6, 1.0, 0.45), Color.WHITE]
	_burst(parent, position, Vector3.UP, colors, 26, 6.0, 0.8, 0.09)


static func _burst(parent: Node, position: Vector3, direction: Vector3, colors: Array, amount: int, speed: float, lifetime: float, size: float) -> void:
	if parent == null:
		return
	if _spark_mesh == null:
		var q := BoxMesh.new()
		q.size = Vector3(1, 1, 0.35)
		_spark_mesh = q
	var p := CPUParticles3D.new()
	p.mesh = _spark_mesh
	p.material_override = _unshaded(Color.WHITE, 1.3)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = lifetime
	p.direction = direction if direction.length() > 0.01 else Vector3.UP
	p.spread = 65.0
	p.initial_velocity_min = speed * 0.45
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -9.0, 0)
	p.damping_min = 1.0
	p.damping_max = 2.5
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size * 1.3
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.7, 0.8))
	curve.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array()
	ramp.colors = PackedColorArray()
	for i in colors.size():
		ramp.add_point(float(i) / maxf(1.0, colors.size() - 1.0), colors[i])
	p.color_initial_ramp = ramp
	parent.add_child(p)
	p.global_position = position
	p.emitting = true
	p.get_tree().create_timer(lifetime + 0.3, false).timeout.connect(p.queue_free)
