class_name Fx
extends RefCounted
## Tiny effect spawners. Everything is short-lived and non-gory:
## energy tracers, spark puffs and confetti pops.

static var _tracer_mesh: BoxMesh
static var _beam_mesh: CylinderMesh
static var _flash_mesh: Mesh
static var _popup_pool: Array[Label3D] = []
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


## A shot's energy streak: a thin flash from the muzzle to the hit point
## plus a travelling bolt.
static func tracer(parent: Node, from: Vector3, to: Vector3, color: Color, width: float) -> void:
	if parent == null or from.distance_to(to) < 0.6:
		return
	if _tracer_mesh == null:
		_tracer_mesh = BoxMesh.new()
		_tracer_mesh.size = Vector3(1, 1, 1)
	if _beam_mesh == null:
		var c := CylinderMesh.new()
		# +Y (top) is the target end: full width there, a hairline at the muzzle.
		c.top_radius = 0.5
		c.bottom_radius = 0.02
		c.height = 1.0
		c.radial_segments = 6
		c.rings = 1
		c.cap_top = false
		c.cap_bottom = false
		_beam_mesh = c
	var key := "beam|" + color.to_html()
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = Color(color.lerp(Color.WHITE, 0.45), 1.0)
		_materials[key] = m
	var t := Tracer.new()
	t.mesh = _beam_mesh
	t.material_override = _materials[key]
	t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(t)
	t.launch(from, to, width, _tracer_mesh, _unshaded(color.lerp(Color.WHITE, 0.55), 1.8))


## Sparks where a shot hits scenery.
static func impact(parent: Node, position: Vector3, normal: Vector3, color: Color) -> void:
	_burst(parent, position, normal, [color, Color.WHITE], 6, 3.0, 0.28, 0.05)


## Colourful pop when a shot lands on a zombie.
static func hit_pop(parent: Node, position: Vector3, direction: Vector3, headshot: bool) -> void:
	var colors := [Color(1.0, 0.35, 0.75), Color(0.3, 0.95, 1.0), Color(1.0, 0.85, 0.25)]
	_burst(parent, position, -direction, colors, 12 if headshot else 6, 4.0, 0.28, 0.08)


## Confetti burst when a defeated zombie pops.
static func confetti(parent: Node, position: Vector3) -> void:
	var colors := [Color(1.0, 0.35, 0.75), Color(0.3, 0.95, 1.0), Color(1.0, 0.85, 0.25), Color(0.6, 1.0, 0.45), Color.WHITE]
	_burst(parent, position, Vector3.UP, colors, 60, 5.0, 1.4, 0.2, 55.0, Vector3(0, -5.0, 0))


## Instant reward on the killing blow: a ring of stars and a bright flash.
static func kill_burst(parent: Node, position: Vector3) -> void:
	var colors := [Color(1.0, 0.85, 0.25), Color(1.0, 0.45, 0.8), Color.WHITE]
	_burst(parent, position, Vector3.UP, colors, 18, 5.5, 0.45, 0.11, 180.0)
	if parent == null:
		return
	if _flash_mesh == null:
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		sphere.radial_segments = 12
		sphere.rings = 6
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = Color(1.0, 0.7, 0.9, 0.9)
		sphere.material = m
		_flash_mesh = sphere
	var flash := MeshInstance3D.new()
	flash.mesh = _flash_mesh
	flash.transparency = 1.0 - 0.9 * Settings.flash_scale()
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(flash)
	flash.global_position = position
	flash.scale = Vector3.ONE * 0.3
	var tw := flash.create_tween().set_parallel(true)
	tw.tween_property(flash, "scale", Vector3.ONE * 1.3, 0.16).set_ease(Tween.EASE_OUT)
	tw.tween_property(flash, "transparency", 1.0, 0.16)
	tw.chain().tween_callback(flash.queue_free)


## Floating "+N" ticket reward above a defeated zombie. Labels are pooled so
## kills don't allocate (and re-rasterise) fresh text objects.
static func ticket_popup(parent: Node, position: Vector3, tickets: int, text_override := "", color := Color(1.0, 0.8, 0.25)) -> void:
	if parent == null or (tickets <= 0 and text_override == ""):
		return
	var label: Label3D = null
	while not _popup_pool.is_empty() and label == null:
		var candidate: Label3D = _popup_pool.pop_back()
		if is_instance_valid(candidate):
			label = candidate
	if label == null:
		label = Label3D.new()
		label.font = UiKit.display_font()
		label.font_size = 96
		label.pixel_size = 0.004
		label.outline_size = 22
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.fixed_size = false
		label.render_priority = 10
		label.outline_render_priority = 9
	if label.get_parent() != parent:
		if label.get_parent():
			label.get_parent().remove_child(label)
		parent.add_child(label)
	label.visible = true
	label.text = text_override if text_override != "" else "+%d" % tickets
	label.modulate = color
	label.outline_modulate = Color(0.12, 0.05, 0.2)
	label.global_position = position
	label.scale = Vector3.ONE * 0.5
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "global_position", position + Vector3.UP * 0.9, 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.35).set_delay(0.6)
	tw.tween_property(label, "outline_modulate:a", 0.0, 0.35).set_delay(0.6)
	tw.chain().tween_callback(func():
		label.visible = false
		_popup_pool.append(label))


static func _burst(parent: Node, position: Vector3, direction: Vector3, colors: Array, amount: int, speed: float, lifetime: float, size: float, spread := 65.0, gravity := Vector3(0, -9.0, 0)) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	if _spark_mesh == null:
		var q := BoxMesh.new()
		q.size = Vector3(1, 1, 1)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		q.material = m
		_spark_mesh = q
	var burst := FxBurst.new()
	burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(burst)
	burst.setup(position, direction, colors, amount, speed, lifetime, size, spread, gravity, _spark_mesh)
