class_name SparkIcon
extends Control
## The Sparks symbol: a gold four-point star with a white centre and a cyan
## glow. Use it next to every Sparks amount (HUD, results, shop, price tags).

var _px := 32.0
## 0-1: a brief extra flare (set to 1 when Sparks arrive; it fades by itself).
var flash := 0.0:
	set(value):
		flash = value
		set_process(flash > 0.0)
		queue_redraw()


func _init(px := 32.0) -> void:
	_px = px
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	set_process(false)


func _process(delta: float) -> void:
	flash = maxf(0.0, flash - delta * 3.0)


func _draw() -> void:
	var centre := size * 0.5
	var radius := _px * 0.5
	draw_circle(centre, radius * (0.95 + 0.25 * flash), Color(Wallet.COLOR_GLOW, 0.16 + 0.3 * flash))
	draw_circle(centre, radius * 0.66, Color(Wallet.COLOR_GLOW, 0.2))
	draw_colored_polygon(star(centre, radius * (1.0 + 0.15 * flash), 0.36), Wallet.COLOR)
	draw_colored_polygon(star(centre, radius * 0.5, 0.42), Color(1.0, 0.98, 0.88))


## A four-point star: tips at `radius`, waist at `radius * pinch`.
static func star(centre: Vector2, radius: float, pinch: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 8:
		var r := radius if i % 2 == 0 else radius * pinch
		var angle := -PI / 2.0 + TAU * i / 8.0
		points.append(centre + Vector2(cos(angle), sin(angle)) * r)
	return points
