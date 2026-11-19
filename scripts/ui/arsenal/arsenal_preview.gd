class_name ArsenalPreview
extends Control
## The Arsenal's showroom: the selected weapon's real model, with its equipped
## cosmetics, turning slowly over a teal pedestal in a night arcade hall
## (ArsenalShowroom). This Control is the reserved rectangle the weapon is
## framed in; drag on it (or push the right stick) to turn the weapon. Its
## overlays (frame, vignette, hint) ignore the mouse.
##
## Framing: the model is scaled so its reach from the turning axis is
## REACH, set on the pedestal, and the camera backs off along a fixed view
## direction until the whole turning envelope fits SAFE of the rectangle:
## the cylinder that every part of the weapon sweeps as it turns (the
## charm's sphere of swing included). So no yaw, charm swing or long muzzle
## can leave the rectangle, and the camera is worked out again whenever the
## weapon or the rectangle changes.
##
## One viewport for every weapon: changing weapon frees the old model. A
## selection must hold SETTLE seconds before its model is built, so rapid
## browsing never builds the models it skips.

const FOV := 30.0
## The camera looks down at the pedestal this much (radians).
const ELEVATION := 0.12
## The model's farthest reach from the turning axis after scaling (metres).
const REACH := 0.6
## Share of the rectangle kept clear on each side (x, y); the bottom also
## keeps HINT_ROOM pixels for the rotation hint (the top keeps as much).
const SAFE_MARGIN := Vector2(0.1, 0.09)
const HINT_ROOM := 64.0
## Resting yaw: the weapon side-on with its muzzle to the left, a little
## turned to the camera.
const BASE_YAW := 0.35
## Idle sway either side of where the weapon was left (radians).
const SWAY := 0.3
const DRAG_SPEED := 0.008
const STICK_SPEED := 2.4
## Seconds a drag holds the weapon where it was left before it sways again.
const HOLD := 2.5
const SETTLE := 0.06
## Circle samples of the envelope when fitting the camera.
const SAMPLES := 32

var weapon: WeaponData
var _viewport: SubViewport
var _camera: Camera3D
var _turntable: Node3D
var _holder: Node3D
var _model: Node3D
var _ring: MeshInstance3D
var _pending: WeaponData
var _pending_age := 0.0
## The turning envelope in turntable space: radius, bottom, top.
var _reach := REACH
var _height := 0.3
var _yaw := BASE_YAW
var _hold := 0.0
var _time := 0.0
var _dragging := false
var _swap: Tween


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	_build_view()
	_build_overlays()
	resized.connect(_fit_camera)
	visibility_changed.connect(func(): set_process(is_visible_in_tree()))


func _build_view() -> void:
	var view := SubViewportContainer.new()
	view.name = "View"
	view.stretch = true
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(view)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	view.add_child(_viewport)
	_ring = ArsenalShowroom.build(_viewport)
	_camera = Camera3D.new()
	_camera.fov = FOV
	_camera.far = 400.0
	_viewport.add_child(_camera)
	_turntable = Node3D.new()
	_turntable.position.y = ArsenalShowroom.TOP + ArsenalShowroom.GAP
	_viewport.add_child(_turntable)
	_holder = Node3D.new()
	_turntable.add_child(_holder)


## A soft vignette, a thin frame and the rotation hint, all mouse-transparent.
func _build_overlays() -> void:
	var vignette := TextureRect.new()
	vignette.name = "Vignette"
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0.07, 0.04, 0.16, 0.0), Color(0.07, 0.04, 0.16, 0.55)])
	grad.offsets = PackedFloat32Array([0.55, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	vignette.texture = tex
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)
	var frame := Panel.new()
	frame.name = "Frame"
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = Color(UiKit.CREAM, 0.28)
	sb.set_border_width_all(2)
	frame.add_theme_stylebox_override("panel", sb)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	add_child(_hint())


## "Drag to rotate" with a mouse glyph, centred on the bottom edge.
func _hint() -> Control:
	var hint := UiKit.key_prompt("LMB", "Drag to rotate")
	hint.name = "RotateHint"
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.offset_bottom = -12.0
	hint.modulate.a = 0.8
	for c in [hint] + hint.find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return hint


## Shows `w`: at once when `instant` (or nothing is shown yet), else once the
## selection has held SETTLE seconds.
func show_weapon(w: WeaponData, instant := false) -> void:
	_pending = w
	_pending_age = 0.0
	if instant or _model == null:
		flush()


## Builds the waiting weapon now.
func flush() -> void:
	if _pending == null:
		return
	var w := _pending
	_pending = null
	if w != weapon or _model == null:
		_build_model(w)


## Rebuilds the shown weapon (its cosmetics or lock changed).
func rebuild() -> void:
	if weapon:
		_build_model(weapon)


func _process(delta: float) -> void:
	_time += delta
	if _pending:
		_pending_age += delta
		if _pending_age >= SETTLE:
			flush()
	var stick := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	if absf(stick) > 0.25:
		_turn(stick * STICK_SPEED * delta)
	_hold = maxf(0.0, _hold - delta)
	var sway := 0.0 if _hold > 0.0 or Settings.reduce_motion() else sin(_time * 0.45) * SWAY
	_turntable.rotation.y = lerp_angle(_turntable.rotation.y, _yaw + sway, minf(1.0, delta * 6.0))


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.button_index == MOUSE_BUTTON_LEFT:
		_dragging = button.pressed
		accept_event()
	elif event is InputEventMouseMotion and (_dragging or (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT):
		_turn((event as InputEventMouseMotion).relative.x * DRAG_SPEED)
		accept_event()
	elif event is InputEventScreenDrag:
		_turn((event as InputEventScreenDrag).relative.x * DRAG_SPEED)
		accept_event()


## Turns the weapon by `radians` and holds it there a moment.
func _turn(radians: float) -> void:
	_yaw += radians
	_hold = HOLD


## Sets the turn at once (the probe checks the framing at several angles).
func set_yaw(radians: float) -> void:
	_yaw = radians
	_hold = HOLD
	_turntable.rotation.y = radians


# --- the model ------------------------------------------------------------------

func _build_model(w: WeaponData) -> void:
	weapon = w
	if _model:
		_holder.remove_child(_model)
		_model.queue_free()
		_model = null
	if w == null or w.viewmodel == null:
		return
	_model = w.viewmodel.instantiate()
	WeaponCosmetics.prepare_preview(_model)
	WeaponCosmetics.apply(_model, w, Cosmetics.weapon_loadout(w.id))
	if not GameData.is_weapon_unlocked(w):
		_tint_locked(_model)
	# Side-on: the barrel (the model's -Z) along the turntable's X.
	_model.rotation.y = PI * 0.5
	_holder.add_child(_model)
	_place_model()
	_tint_ring(w)
	_yaw = BASE_YAW
	_hold = 0.0
	_turntable.rotation.y = _yaw
	_pop_in()


## Scales and centres the model over the axis, resting GAP over the pedestal,
## and works out its turning envelope.
func _place_model() -> void:
	var parts := measure(_model, Transform3D(Basis.from_euler(_model.rotation), Vector3.ZERO))
	var corners: PackedVector3Array = parts["corners"]
	var bounds := AABB(corners[0], Vector3.ZERO) if not corners.is_empty() else AABB()
	for c in corners:
		bounds = bounds.expand(c)
	var axis := Vector3(bounds.get_center().x, 0.0, bounds.get_center().z)
	var reach := 0.01
	var low := bounds.position.y
	var high := bounds.end.y
	for c in corners:
		reach = maxf(reach, Vector2(c.x - axis.x, c.z - axis.z).length())
	var swing_reach := reach
	for sphere: Array in parts["spheres"]:
		var at: Vector3 = sphere[0]
		var radius: float = sphere[1]
		swing_reach = maxf(swing_reach, Vector2(at.x - axis.x, at.z - axis.z).length() + radius)
		low = minf(low, at.y - radius)
		high = maxf(high, at.y + radius)
	var k := REACH / reach
	_holder.scale = Vector3.ONE * k
	_model.position = -Vector3(axis.x, low, axis.z)
	# The circle samples lie a little inside the true circle: allow for it.
	_reach = swing_reach * k / cos(PI / SAMPLES)
	_height = (high - low) * k
	_fit_camera()


## Every visible part of `model` as box corners, and each charm as a sphere
## [centre, radius] it can swing anywhere inside, all in the space `xf` maps
## the model into.
static func measure(model: Node3D, xf: Transform3D) -> Dictionary:
	var corners := PackedVector3Array()
	var spheres: Array = []
	for node in model.find_children("*", "GeometryInstance3D", true, false):
		var gi := node as GeometryInstance3D
		if not _shown(model, gi) or _charm_of(model, gi):
			continue
		var to := xf * _relative(model, gi)
		var box := gi.get_aabb()
		for i in 8:
			corners.append(to * box.get_endpoint(i))
	for node in model.find_children("*", "WeaponCharm", true, false):
		var charm := node as Node3D
		var radius := 0.0
		for mesh in charm.find_children("*", "GeometryInstance3D", true, false):
			var box := (mesh as GeometryInstance3D).get_aabb()
			var in_charm := _relative(charm, mesh as Node3D)
			for i in 8:
				radius = maxf(radius, (in_charm * box.get_endpoint(i)).length())
		var at := xf * _relative(model, charm)
		spheres.append([at.origin, radius * at.basis.get_scale().x])
	return {"corners": corners, "spheres": spheres}


static func _charm_of(model: Node3D, node: Node) -> bool:
	var n := node.get_parent()
	while n and n != model:
		if n is WeaponCharm:
			return true
		n = n.get_parent()
	return false


static func _shown(model: Node3D, node: Node3D) -> bool:
	var n: Node = node
	while n and n != model:
		if n is Node3D and not (n as Node3D).visible:
			return false
		n = n.get_parent()
	return true


## `child`'s transform in `root`'s space (works before the nodes enter the tree).
static func _relative(root: Node3D, child: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = child
	while n and n != root:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


## Locked weapons show as a dark silhouette with a faint rim.
static func _tint_locked(node: Node) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.13, 0.26)
	m.rim_enabled = true
	m.rim = 0.6
	m.roughness = 0.8
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = m


func _tint_ring(w: WeaponData) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = w.tracer_color.lerp(UiKit.CYAN, 0.35)
	_ring.material_override = m


## The new weapon grows in from a little smaller (never larger: it stays inside its frame).
func _pop_in() -> void:
	if _swap and _swap.is_valid():
		_swap.kill()
	_turntable.scale = Vector3.ONE
	if Settings.reduce_motion() or not is_visible_in_tree():
		return
	_turntable.scale = Vector3.ONE * 0.9
	_swap = create_tween()
	_swap.tween_property(_turntable, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# --- the camera -----------------------------------------------------------------

## The part of the rectangle the weapon must stay inside (local pixels).
func safe_rect() -> Rect2:
	var margin := Vector2(size.x * SAFE_MARGIN.x, maxf(size.y * SAFE_MARGIN.y, HINT_ROOM))
	return Rect2(margin, size - margin * 2.0)


## Backs the camera off along its view direction until every sample of the
## turning envelope projects inside safe_rect().
func _fit_camera() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	var safe := safe_rect()
	var half_v := tan(deg_to_rad(FOV) * 0.5)
	var half_h := half_v * size.x / size.y
	var fx := safe.size.x / size.x * half_h
	var fy := safe.size.y / size.y * half_v
	var back := Vector3(0.0, sin(ELEVATION), cos(ELEVATION))
	var up := Vector3(0.0, cos(ELEVATION), -sin(ELEVATION))
	var middle := _turntable.position + Vector3(0.0, _height * 0.5, 0.0)
	var distance := 0.0
	for y in [-_height * 0.5, _height * 0.5]:
		for i in SAMPLES:
			var a := TAU * i / SAMPLES
			var p := Vector3(cos(a) * _reach, y, sin(a) * _reach)
			var depth := p.dot(back)
			distance = maxf(distance, depth + absf(p.x) / fx)
			distance = maxf(distance, depth + absf(p.dot(up)) / fy)
	_camera.transform = Transform3D(Basis(Vector3.RIGHT, up, back), middle + back * distance)


# --- for the probe ----------------------------------------------------------------

func model() -> Node3D:
	return _model


func camera() -> Camera3D:
	return _camera


## True while a selection waits for its model to be built.
func waiting() -> bool:
	return _pending != null
