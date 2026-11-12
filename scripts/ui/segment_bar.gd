class_name SegmentBar
extends Control
## Segmented health bar (five chunky cells, like the reference HUD). An
## overshield shows as extra cyan cells after the health cells: damage eats
## those first.

const SHIELD_COLOR := Color(0.35, 0.93, 1.0)

@export var segments := 5
@export var gap := 8.0

var value := 1.0: set = set_value
var flash := 0.0
## Overshield, as a fraction of maximum health (0.5 = two and a half cells).
var shield := 0.0: set = set_shield
var shield_flash := 0.0

var _plate := StyleBoxFlat.new()
var _back := StyleBoxFlat.new()
var _cell := StyleBoxFlat.new()
var _time := 0.0


func _ready() -> void:
	_plate.bg_color = Color(UiKit.INK, 0.75)
	_plate.set_corner_radius_all(12)
	_plate.set_expand_margin_all(8)
	_back.set_corner_radius_all(7)
	_cell.set_corner_radius_all(7)
	_cell.border_width_top = 5


func set_value(v: float) -> void:
	value = clampf(v, 0.0, 1.0)
	queue_redraw()


func set_shield(v: float) -> void:
	shield = maxf(0.0, v)
	queue_redraw()


func _process(delta: float) -> void:
	if flash > 0.0 or shield_flash > 0.0 or shield > 0.0:
		flash = maxf(0.0, flash - delta * 3.0)
		shield_flash = maxf(0.0, shield_flash - delta * 3.0)
		_time += delta
		queue_redraw()


func _draw() -> void:
	var w := (size.x - gap * (segments - 1)) / segments
	var shield_cells := int(ceil(shield * segments - 0.001))
	var color := UiKit.GREEN
	if value <= 0.2:
		color = UiKit.RED
	elif value <= 0.4:
		color = UiKit.AMBER
	color = color.lerp(Color.WHITE, flash)
	# Backing plate, stretched over the shield cells when there are any.
	draw_style_box(_plate, Rect2(0, 0, size.x + shield_cells * (w + gap), size.y))
	for i in segments:
		_draw_cell(Rect2(i * (w + gap), 0, w, size.y), clampf(value * segments - i, 0.0, 1.0), color, Color(0.1, 0.16, 0.12, 0.9))
	if shield_cells == 0:
		return
	var shimmer := 0.12 * sin(_time * 3.0)
	var shield_color := SHIELD_COLOR.lerp(Color.WHITE, maxf(shield_flash, shimmer))
	for i in shield_cells:
		var rect := Rect2(size.x + gap + i * (w + gap), 0, w, size.y)
		_draw_cell(rect, clampf(shield * segments - i, 0.0, 1.0), shield_color, Color(0.08, 0.14, 0.2, 0.9))
		# Diagonal glints mark the cells as shield, not health.
		var fill_w := w * clampf(shield * segments - i, 0.0, 1.0)
		for k in 3:
			var x := rect.position.x + 10.0 + k * 18.0
			if x + 10.0 < rect.position.x + fill_w:
				draw_line(Vector2(x, size.y - 8.0), Vector2(x + 10.0, 10.0), Color(1, 1, 1, 0.35), 3.0, true)


func _draw_cell(rect: Rect2, fill: float, color: Color, back_color: Color) -> void:
	_back.bg_color = back_color
	draw_style_box(_back, rect)
	if fill <= 0.0:
		return
	_cell.bg_color = color
	_cell.border_color = color.lightened(0.45)
	draw_style_box(_cell, Rect2(rect.position, Vector2(maxf(8.0, rect.size.x * fill), rect.size.y)))
