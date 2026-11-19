class_name SparkIcon
extends Control
## The Arcade Token symbol (Wallet's currency, still called Sparks in code and
## saves): a gold coin with a notched rim and a stamped star, drawn at any size.
## Use it next to every token amount (HUD, results, reward rows).

const RIM := Color("f2b233")
const RIM_DARK := Color("6a3306")
const RIM_LIGHT := Color("ffe9a0")
const STAMP := Color("ffc23a")
const STAMP_SHADOW := Color("8a4606")

var _px := 32.0
## 0-1: a brief extra flare (set to 1 when tokens arrive; it fades by itself).
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
	var radius := _px * 0.5 * (1.0 + 0.1 * flash)
	if flash > 0.0:
		draw_circle(centre, radius * 1.25, Color(Wallet.COLOR, 0.35 * flash))
	draw_circle(centre, radius * 0.96, RIM_DARK)
	draw_circle(centre, radius * 0.88, RIM)
	draw_arc(centre, radius * 0.8, PI * 0.9, PI * 1.85, 24, RIM_LIGHT, maxf(1.0, radius * 0.08), true)
	draw_circle(centre, radius * 0.7, RIM_DARK)
	draw_circle(centre, radius * 0.64, Wallet.COLOR)
	draw_colored_polygon(star(centre + Vector2(0.0, radius * 0.07), radius * 0.48, 0.42), STAMP_SHADOW)
	draw_colored_polygon(star(centre, radius * 0.46, 0.42), STAMP)
	draw_circle(centre + Vector2(-0.32, -0.36) * radius, radius * 0.1, Color(1.0, 1.0, 1.0, 0.75))


## A five-point star: tips at `radius`, inner corners at `radius * pinch`.
static func star(centre: Vector2, radius: float, pinch: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 10:
		var r := radius if i % 2 == 0 else radius * pinch
		var angle := -PI / 2.0 + TAU * i / 10.0
		points.append(centre + Vector2(cos(angle), sin(angle)) * r)
	return points
