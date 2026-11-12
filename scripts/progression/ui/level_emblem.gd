class_name LevelEmblem
extends Control
## Chunky hexagonal account-level badge with the level number. The colour
## steps up every ten levels; level 50 cycles through the rainbow.

var level := 1:
	set(v):
		level = v
		queue_redraw()
## 0-1 white flash, set to 1 on a level-up and faded out here.
var flash := 0.0

var _time := 0.0


func _init(lvl := 1, height := 64.0) -> void:
	level = lvl
	custom_minimum_size = Vector2(height * 0.9, height)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time += delta
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 1.4)
		queue_redraw()
	elif level >= Progression.MAX_LEVEL:
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.y * 0.5, size.x / 1.732)
	var col := ProgStyle.level_color(level, _time)
	ProgStyle.fill_gradient(self, ProgStyle.polygon(c + Vector2(0, r * 0.09), r, 6), Color(UiKit.INK, 0.55), Color(UiKit.INK, 0.55))
	ProgStyle.fill_gradient(self, ProgStyle.polygon(c, r, 6), col.lightened(0.35), col.darkened(0.45))
	ProgStyle.fill_gradient(self, ProgStyle.polygon(c, r * 0.76, 6), Color("2a1f63"), UiKit.INK)
	ProgStyle.outline(self, ProgStyle.polygon(c, r * 0.76, 6), Color(col, 0.75), maxf(1.5, r * 0.05))
	# Gloss on the upper rim.
	var gloss := ProgStyle.polygon(c, r * 0.94, 6)
	draw_polyline(PackedVector2Array([gloss[4], gloss[5], gloss[0], gloss[1]]), Color(1, 1, 1, 0.45), maxf(1.0, r * 0.06), true)
	var font := UiKit.display_font()
	var text := str(level)
	var fs := int(r * (0.95 if text.length() < 2 else 0.82))
	var base_y := c.y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	var pos := Vector2(0, base_y)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, maxi(4, fs / 6), Color(UiKit.INK, 0.9))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Color.WHITE)
	if flash > 0.0:
		ProgStyle.fill_gradient(self, ProgStyle.polygon(c, r, 6), Color(1, 1, 1, flash * 0.8), Color(col.lightened(0.5), flash * 0.5))
