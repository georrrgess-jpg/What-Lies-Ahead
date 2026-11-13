class_name ReloadArc
extends Control
## Ring around the reticle that fills while reloading, led by a bright dot.

const RADIUS := 34.0

var progress := -1.0:
	set(v):
		if not is_equal_approx(v, progress):
			progress = v
			queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if progress < 0.0:
		return
	var c := size * 0.5
	var start := -PI * 0.5
	var k := clampf(progress, 0.0, 1.0)
	draw_arc(c, RADIUS, 0.0, TAU, 48, Color(0.05, 0.0, 0.1, 0.55), 9.0, true)
	draw_arc(c, RADIUS, start, start + TAU * k, 48, UiKit.CYAN, 5.0, true)
	# A bright head leads the fill, so slow reloads still read as moving.
	var head := c + Vector2(cos(start + TAU * k), sin(start + TAU * k)) * RADIUS
	draw_circle(head, 5.5, Color(0.05, 0.0, 0.1, 0.7))
	draw_circle(head, 3.6, Color.WHITE)
