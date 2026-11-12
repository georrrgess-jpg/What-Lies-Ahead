class_name SegmentBar
extends Control
## Segmented health bar (five chunky cells, like the reference HUD).

@export var segments := 5
@export var gap := 8.0

var value := 1.0: set = set_value
var flash := 0.0


func set_value(v: float) -> void:
	value = clampf(v, 0.0, 1.0)
	queue_redraw()


func _process(delta: float) -> void:
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 3.0)
		queue_redraw()


func _draw() -> void:
	var w := (size.x - gap * (segments - 1)) / segments
	var color := UiKit.GREEN
	if value <= 0.2:
		color = UiKit.RED
	elif value <= 0.4:
		color = UiKit.AMBER
	color = color.lerp(Color.WHITE, flash)
	# Backing plate.
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(UiKit.INK, 0.75)
	plate.set_corner_radius_all(12)
	plate.set_expand_margin_all(8)
	draw_style_box(plate, Rect2(Vector2.ZERO, size))
	for i in segments:
		var fill := clampf(value * segments - i, 0.0, 1.0)
		var rect := Rect2(i * (w + gap), 0, w, size.y)
		var back := StyleBoxFlat.new()
		back.bg_color = Color(0.1, 0.16, 0.12, 0.9)
		back.set_corner_radius_all(7)
		draw_style_box(back, rect)
		if fill > 0.0:
			var cell := StyleBoxFlat.new()
			cell.bg_color = color
			cell.set_corner_radius_all(7)
			cell.border_color = color.lightened(0.45)
			cell.border_width_top = 5
			draw_style_box(cell, Rect2(rect.position, Vector2(maxf(8.0, w * fill), size.y)))
