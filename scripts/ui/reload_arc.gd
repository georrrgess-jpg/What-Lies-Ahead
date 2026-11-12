class_name ReloadArc
extends Control
## Ring around the reticle that fills while reloading.

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
	draw_arc(c, 34.0, 0.0, TAU, 48, Color(0.05, 0.0, 0.1, 0.55), 9.0, true)
	draw_arc(c, 34.0, start, start + TAU * clampf(progress, 0.0, 1.0), 48, UiKit.CYAN, 5.0, true)
