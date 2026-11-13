class_name OperatorPreview
extends SubViewportContainer
## Shows an operator in 3D on a transparent background: idle animation, a
## slow turntable (drag to spin it), studio lighting and a soft floor shadow.
## By default it follows the equipped operator; call show_operator() to show
## a specific one (the Locker does). Works in paused trees (results screen).
##
##   var p := OperatorPreview.new()
##   p.custom_minimum_size = Vector2(360, 520)
##   p.framing = OperatorPreview.Framing.FULL   # or PORTRAIT (head and shoulders)

enum Framing { FULL, PORTRAIT }

## Follow the equipped operator (and play its flourish when it changes).
var follow_equipped := true
var framing := Framing.FULL
## Degrees per second; 0 holds the operator facing the camera.
var turntable_speed := 14.0
## Draws a glowing pedestal under the operator.
var pedestal := false
## The operator shown (null = default operator).
var item: CosmeticItem

var _viewport: SubViewport
var _camera: Camera3D
var _pivot: Node3D
var _model: Node3D
var _yaw := 18.0
var _dragging := false
var _drag_idle := 0.0


func _ready() -> void:
	stretch = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_PASS
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_viewport)
	_build_stage()
	if follow_equipped:
		Cosmetics.equipped_changed.connect(_on_equipped_changed)
		item = Operators.equipped()
	_spawn(false)


func _build_stage() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.74, 0.98)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	_viewport.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-34, 32, 0)
	key.light_energy = 1.3
	key.light_color = Color(1.0, 0.92, 0.84)
	_viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-18, 160, 0)
	rim.light_energy = 1.1
	rim.light_color = Color(0.45, 0.9, 1.0)
	_viewport.add_child(rim)
	var rim2 := DirectionalLight3D.new()
	rim2.rotation_degrees = Vector3(-10, -150, 0)
	rim2.light_energy = 0.8
	rim2.light_color = Color(1.0, 0.45, 0.8)
	_viewport.add_child(rim2)
	# A low warm fill keeps chins, hat brims and visors from going dark.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(18, -24, 0)
	fill.light_energy = 0.3
	fill.light_color = Color(1.0, 0.8, 0.7)
	_viewport.add_child(fill)
	_camera = Camera3D.new()
	_camera.fov = 30.0
	_viewport.add_child(_camera)
	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	_viewport.add_child(_floor_shadow())
	if pedestal:
		_viewport.add_child(_pedestal())
	_frame_camera()


func _frame_camera() -> void:
	if framing == Framing.PORTRAIT:
		_camera.position = Vector3(0, 1.7, 2.2)
		_camera.look_at(Vector3(0, 1.63, 0))
	else:
		_camera.position = Vector3(0, 1.2, 5.5)
		_camera.look_at(Vector3(0, 1.04, 0))


func _floor_shadow() -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.4, 1.4)
	quad.orientation = PlaneMesh.FACE_Y
	var m := ShaderMaterial.new()
	m.shader = _shadow_shader()
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = m
	mi.position.y = 0.005
	return mi


static var _shadow: Shader


static func _shadow_shader() -> Shader:
	if _shadow == null:
		_shadow = Shader.new()
		_shadow.code = """shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	ALBEDO = vec3(0.05, 0.02, 0.12);
	ALPHA = smoothstep(1.0, 0.2, d) * 0.55;
}"""
	return _shadow


func _pedestal() -> Node3D:
	var root := Node3D.new()
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.72
	cyl.bottom_radius = 0.78
	cyl.height = 0.12
	cyl.radial_segments = 48
	disc.mesh = cyl
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(UiKit.NAVY, 1.0)
	m.roughness = 0.35
	m.metallic = 0.3
	disc.material_override = m
	disc.position.y = -0.06
	root.add_child(disc)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.74
	torus.outer_radius = 0.78
	torus.rings = 48
	ring.mesh = torus
	var g := StandardMaterial3D.new()
	g.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	g.albedo_color = UiKit.CYAN
	ring.material_override = g
	ring.position.y = -0.005
	root.add_child(ring)
	return root


## Shows `it` (null = default operator). `flourish` plays its Pose clip.
func show_operator(it: CosmeticItem, flourish := false) -> void:
	item = it
	if is_inside_tree():
		_spawn(flourish)


func _spawn(flourish: bool) -> void:
	if _pivot == null:
		return
	if _model:
		_model.queue_free()
	_model = Operators.instantiate(item)
	_pivot.add_child(_model)
	if framing == Framing.PORTRAIT:
		# Portraits hold a still, flattering frame of the idle (no drifting out of shot).
		var anim := Operators.animation_player(_model)
		if anim:
			anim.seek(0.4, true)
			anim.speed_scale = 0.6
	if flourish:
		Operators.play_pose(_model)


func _on_equipped_changed(slot: StringName, _weapon_id: StringName) -> void:
	if slot == &"avatar":
		show_operator(Operators.equipped(), true)


func _process(delta: float) -> void:
	if _pivot == null or not is_visible_in_tree():
		return
	if not _dragging:
		_drag_idle += delta
		if _drag_idle > 1.5:
			_yaw += turntable_speed * delta
	_pivot.rotation_degrees.y = _yaw


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and event.double_click and _model:
			Operators.play(_model, "Wave")
		_dragging = event.pressed
		_drag_idle = 0.0
	elif event is InputEventMouseMotion and _dragging:
		_yaw += event.relative.x * 0.5
		_drag_idle = 0.0
