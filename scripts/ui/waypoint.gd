class_name Waypoint
extends Control
## Screen-space marker for a world position: an icon + label + distance that
## sits over the target when it is on screen and clamps to the screen edge with
## an arrow when it is not. Used for the loadout station and the exit portal.

var target: Node3D
var offset := Vector3(0, 6.5, 0)
var label := "LOADOUT"
var color := UiKit.AMBER
var icon := "kiosk"     # "kiosk" or "portal"
var camera: Camera3D
var _time := 0.0
var _text: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_text = UiKit.arcade_label("", 26, color)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.custom_minimum_size = Vector2(220, 0)
	add_child(_text)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if not visible or target == null or camera == null or not is_instance_valid(target):
		_text.visible = false
		return
	var world := target.global_position + offset
	var distance := camera.global_position.distance_to(target.global_position)
	var screen := _project(world)
	_text.visible = distance > 4.0
	_text.text = "%s\n%d m" % [label, int(distance)]
	_text.add_theme_color_override("font_color", color)
	_text.position = screen + Vector2(-110, 30)


## Projects to the screen, clamping to an inset border when off-screen/behind.
func _project(world: Vector3) -> Vector2:
	var rect := get_viewport_rect().size
	var margin := 90.0
	var behind := camera.is_position_behind(world)
	var p := camera.unproject_position(world)
	if behind:
		p = rect - p
	var inside := not behind and p.x > margin and p.x < rect.x - margin and p.y > margin and p.y < rect.y - margin
	if not inside:
		var c := rect * 0.5
		var d := (p - c)
		if behind:
			d.y = absf(d.y) + 1.0
		var sx := (rect.x * 0.5 - margin) / maxf(0.001, absf(d.x))
		var sy := (rect.y * 0.5 - margin) / maxf(0.001, absf(d.y))
		p = c + d * minf(sx, sy)
	return p


func _draw() -> void:
	if not visible or target == null or camera == null or not is_instance_valid(target):
		return
	var world := target.global_position + offset
	var p := _project(world)
	var bob := sin(_time * 4.0) * 4.0
	var pulse := 0.75 + 0.25 * sin(_time * 6.0)
	var dark := Color(UiKit.INK, 0.85)
	var c := Color(color, pulse)
	var at := p + Vector2(0, bob)
	# Diamond badge with an icon.
	var r := 26.0
	var diamond := PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)])
	var outer := PackedVector2Array([at + Vector2(0, -r - 5), at + Vector2(r + 5, 0), at + Vector2(0, r + 5), at + Vector2(-r - 5, 0)])
	draw_colored_polygon(outer, dark)
	draw_colored_polygon(diamond, c)
	if icon == "portal":
		draw_arc(at, 10.0, 0, TAU, 24, dark, 4.0, true)
		draw_arc(at, 4.0, 0, TAU, 12, dark, 3.0, true)
	else:
		# A little star (the kiosk's emblem).
		var pts := PackedVector2Array()
		for k in 10:
			var rr := 12.0 if k % 2 == 0 else 5.0
			var a := -PI * 0.5 + PI * k / 5.0
			pts.append(at + Vector2(cos(a), sin(a)) * rr)
		draw_colored_polygon(pts, dark)
	# Down-pointing tick under the badge.
	draw_colored_polygon(PackedVector2Array([at + Vector2(-8, r + 8), at + Vector2(8, r + 8), at + Vector2(0, r + 18)]), c)
