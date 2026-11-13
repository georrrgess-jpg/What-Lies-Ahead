class_name Waypoint
extends Control
## Screen-space marker for a world position: a diamond badge with an icon,
## and under it the name and distance. It sits over the target when that is
## on screen; otherwise it clamps to the screen edge and grows an arrow that
## points the way. Used for the loadout station and the exit portal.
##
## It only runs while it is visible, and the text changes only when the
## distance does.

const BADGE := 26.0
const EDGE_MARGIN := 96.0

var target: Node3D
var offset := Vector3(0, 6.5, 0)
var label := "LOADOUT"
var color := UiKit.AMBER
## "kiosk" or "portal".
var icon := "kiosk"
var camera: Camera3D

var _time := 0.0
var _text: Label
var _metres := -1
var _at := Vector2.ZERO
var _clamped := false
var _diamond := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _arrow := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_text = UiKit.arcade_label("", 26, color)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.custom_minimum_size = Vector2(260, 0)
	_text.add_theme_constant_override("line_spacing", -8)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_text)
	visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()


func _on_visibility_changed() -> void:
	set_process(is_visible_in_tree())


func _process(delta: float) -> void:
	_time += delta
	if target == null or camera == null or not is_instance_valid(target):
		_text.visible = false
		return
	var distance := camera.global_position.distance_to(target.global_position)
	_at = _project(target.global_position + offset)
	_text.visible = distance > 4.0
	var metres := int(distance)
	if metres != _metres:
		_metres = metres
		_text.text = "%s\n%d m" % [label, metres]
		_text.add_theme_color_override("font_color", color)
	if _clamped:
		# At the edge the text moves to the inner side, clear of the arrow.
		_text.position = _at + (size * 0.5 - _at).normalized() * 92.0 - Vector2(130.0, 30.0)
	else:
		_text.position = _at + Vector2(-130.0, BADGE + 24.0)
	queue_redraw()


## Projects to the screen, clamping to an inset border when off-screen/behind.
func _project(world: Vector3) -> Vector2:
	var rect := get_viewport_rect().size
	var behind := camera.is_position_behind(world)
	var p := camera.unproject_position(world)
	if behind:
		p = rect - p
	_clamped = behind or p.x < EDGE_MARGIN or p.x > rect.x - EDGE_MARGIN or p.y < EDGE_MARGIN or p.y > rect.y - EDGE_MARGIN
	if _clamped:
		var c := rect * 0.5
		var d := p - c
		if behind:
			d.y = absf(d.y) + 1.0
		var sx := (rect.x * 0.5 - EDGE_MARGIN) / maxf(0.001, absf(d.x))
		var sy := (rect.y * 0.5 - EDGE_MARGIN) / maxf(0.001, absf(d.y))
		p = c + d * minf(sx, sy)
	return p


func _draw() -> void:
	if target == null or camera == null or not is_instance_valid(target):
		return
	var pulse := 0.8 + 0.2 * sin(_time * 6.0)
	var dark := Color(UiKit.INK, 0.88)
	var at := _at + Vector2(0.0, sin(_time * 4.0) * 4.0)
	_set_diamond(at, BADGE + 6.0)
	draw_colored_polygon(_diamond, dark)
	_set_diamond(at, BADGE)
	draw_colored_polygon(_diamond, Color(color, pulse))
	HudIcon.paint(self, &"portal" if icon == "portal" else &"star", at, 26.0, dark)
	# On target: a tick under the badge. Off screen: an arrow pointing the way.
	var dir := Vector2.DOWN
	if _clamped:
		dir = (at - size * 0.5).normalized()
	var side := Vector2(-dir.y, dir.x)
	var base := at + dir * (BADGE + 10.0)
	var reach := 20.0 if _clamped else 11.0
	_arrow[0] = base + dir * reach
	_arrow[1] = base + side * reach * 0.8
	_arrow[2] = base - side * reach * 0.8
	draw_colored_polygon(_arrow, Color(color, pulse))


func _set_diamond(at: Vector2, r: float) -> void:
	_diamond[0] = at + Vector2(0, -r)
	_diamond[1] = at + Vector2(r, 0)
	_diamond[2] = at + Vector2(0, r)
	_diamond[3] = at + Vector2(-r, 0)
