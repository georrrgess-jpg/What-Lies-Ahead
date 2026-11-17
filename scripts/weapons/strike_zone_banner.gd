class_name StrikeZoneBanner
extends Node3D
## The Strike Zone's "STRIKE!" banner: big arcade letters over a
## starburst where the fifth pin went down, the same size on screen at any
## distance. It slams in oversized, settles with a wobble, rises a little and
## shrinks away. Back-to-back strikes climb the bowling ladder: DOUBLE!, then
## TURKEY! (and the colours warm up). Pooled, like KillPopup.

const LIFE := 1.15
const FADE := 0.3
const RISE := 0.5
const OUTLINE := Color(0.14, 0.04, 0.22)
## [title, title colour, burst colour] per rung of the ladder.
const RUNGS := [["STRIKE!", Color(1.0, 0.95, 0.4), Color(1.0, 0.3, 0.62)], ["DOUBLE!", Color(0.45, 1.0, 1.0), Color(1.0, 0.85, 0.3)],
	["TURKEY!", Color(1.0, 0.62, 0.25), Color(1.0, 0.95, 0.4)]]

static var _pool: Array = []
static var _burst_mesh: ArrayMesh

var _title: Label3D
var _sub: Label3D
var _burst: MeshInstance3D
var _burst_mat: StandardMaterial3D
var _tween: Tween


## Pops the banner for ladder rung `rung` (1 = STRIKE!) at `at` under `parent`.
static func spawn(parent: Node, at: Vector3, rung: int) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var b: StrikeZoneBanner = null
	while not _pool.is_empty() and b == null:
		var candidate = _pool.pop_back()
		if is_instance_valid(candidate) and candidate.is_inside_tree():
			b = candidate
	if b == null:
		b = StrikeZoneBanner.new()
	if b.get_parent() != parent:
		if b.get_parent():
			b.get_parent().remove_child(b)
		parent.add_child(b)
	b._play(at, clampi(rung, 1, RUNGS.size()), rung)


func _init() -> void:
	_burst = MeshInstance3D.new()
	_burst.mesh = _star_burst()
	_burst_mat = StandardMaterial3D.new()
	_burst_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_burst_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_burst_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_burst_mat.billboard_keep_scale = true
	_burst_mat.no_depth_test = true
	_burst_mat.fixed_size = true
	_burst_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_burst_mat.render_priority = 8
	_burst.material_override = _burst_mat
	_burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_burst)
	_title = _label(112, 0.0015, 0.0)
	_sub = _label(48, 0.0015, -92.0)


## A label `drop` pixels below the banner's centre.
func _label(font_size: int, pixel: float, drop: float) -> Label3D:
	var l := Label3D.new()
	l.font = UiKit.display_font()
	l.font_size = font_size
	l.pixel_size = pixel
	l.outline_size = int(font_size * 0.22)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.render_priority = 10
	l.outline_render_priority = 9
	l.offset = Vector2(0.0, drop)
	add_child(l)
	return l


func _play(at: Vector3, rung_index: int, rung: int) -> void:
	var r: Array = RUNGS[rung_index - 1]
	visible = true
	global_position = at
	_title.text = r[0]
	_sub.text = "%d IN A ROW" % rung if rung > 1 else "ALL PINS DOWN"
	var title_color: Color = r[1]
	var burst_color: Color = r[2]
	_set_alpha(title_color, burst_color, 1.0)
	_title.scale = Vector3.ONE * 2.2
	_sub.scale = Vector3.ONE * 0.01
	_burst.scale = Vector3.ONE * 0.15
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_title, "scale", Vector3.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_burst, "scale", Vector3.ONE * 0.75, 0.32).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_sub, "scale", Vector3.ONE, 0.18).set_delay(0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_wobble, 0.0, 1.0, 0.6).set_delay(0.2)
	_tween.tween_property(self, "global_position", at + Vector3.UP * RISE, LIFE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(func(a: float): _set_alpha(title_color, burst_color, a), 1.0, 0.0, FADE).set_delay(LIFE - FADE)
	_tween.tween_property(_title, "scale", Vector3.ONE * 0.7, FADE).set_delay(LIFE - FADE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(_release)


## A settling wiggle of the title (k 0-1 over the wobble).
func _wobble(k: float) -> void:
	_title.rotation.z = sin(k * TAU * 2.0) * 0.12 * (1.0 - k)


func _set_alpha(title_color: Color, burst_color: Color, alpha: float) -> void:
	_title.modulate = Color(title_color, alpha)
	_title.outline_modulate = Color(OUTLINE, alpha)
	_sub.modulate = Color(1.0, 1.0, 1.0, alpha)
	_sub.outline_modulate = Color(OUTLINE, alpha)
	_burst_mat.albedo_color = Color(burst_color, 0.75 * alpha)


func _release() -> void:
	visible = false
	_pool.append(self)


## A twelve-pointed starburst behind the title (built once, shared).
static func _star_burst() -> ArrayMesh:
	if _burst_mesh:
		return _burst_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := 12
	for i in points * 2:
		var a0 := i * PI / points
		var a1 := (i + 1) * PI / points
		var r0 := 0.34 if i % 2 == 0 else 0.2
		var r1 := 0.2 if i % 2 == 0 else 0.34
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(cos(a0) * r0, sin(a0) * r0 * 0.62, 0.0))
		st.add_vertex(Vector3(cos(a1) * r1, sin(a1) * r1 * 0.62, 0.0))
	_burst_mesh = st.commit()
	return _burst_mesh
