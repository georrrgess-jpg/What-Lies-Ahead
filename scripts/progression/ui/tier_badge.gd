class_name TierBadge
extends Control
## Weapon mastery badge: a pointed shield in the tier colour (Bronze, Silver,
## Gold, Diamond, Prismatic) with the rank number. Grey outline at rank 0.
## Diamond gets facet lines; Prismatic cycles through the rainbow.

var rank := 0:
	set(v):
		rank = v
		queue_redraw()
var flash := 0.0

var _time := 0.0


func _init(rank_number := 0, height := 64.0) -> void:
	rank = rank_number
	custom_minimum_size = Vector2(height * 0.86, height)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time += delta
	var t := Mastery.tier(rank)
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 1.4)
		queue_redraw()
	elif t and t.animated:
		queue_redraw()


## Shield outline scaled to `s` around `c`.
static func shield(c: Vector2, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([
		c + Vector2(-w, -h), c + Vector2(0, -h * 1.12), c + Vector2(w, -h),
		c + Vector2(w, h * 0.2), c + Vector2(0, h), c + Vector2(-w, h * 0.2)])


func _draw() -> void:
	var c := size * 0.5 + Vector2(0, size.y * 0.03)
	var h := size.y * 0.44
	var w := minf(size.x * 0.46, h * 0.86)
	var t := Mastery.tier(rank)
	var col := ProgStyle.rank_color(rank, _time)
	if t == null:
		ProgStyle.fill_gradient(self, shield(c, w, h), Color(UiKit.INK, 0.8), Color(UiKit.INK, 0.8))
		ProgStyle.outline(self, shield(c, w * 0.92, h * 0.92), Color(1, 1, 1, 0.3), maxf(1.5, h * 0.06))
		_number("–", c, h, Color(1, 1, 1, 0.5))
		return
	ProgStyle.fill_gradient(self, shield(c + Vector2(0, h * 0.1), w, h), Color(UiKit.INK, 0.55), Color(UiKit.INK, 0.55))
	ProgStyle.fill_gradient(self, shield(c, w, h), t.highlight if not t.animated else col.lightened(0.4), col.darkened(0.5))
	var inner := shield(c, w * 0.74, h * 0.74)
	ProgStyle.fill_gradient(self, inner, col.lightened(0.15), col.darkened(0.25))
	if t.id == &"diamond" or t.animated:
		for i in inner.size():
			draw_line(c + Vector2(0, -h * 0.15), inner[i], Color(1, 1, 1, 0.28), maxf(1.0, h * 0.03), true)
	ProgStyle.outline(self, inner, Color(1, 1, 1, 0.55), maxf(1.0, h * 0.045))
	_number(str(rank), c + Vector2(0, -h * 0.06), h, Color.WHITE)
	if flash > 0.0:
		ProgStyle.fill_gradient(self, shield(c, w, h), Color(1, 1, 1, flash * 0.85), Color(col.lightened(0.5), flash * 0.5))


func _number(text: String, c: Vector2, h: float, color: Color) -> void:
	var font := UiKit.display_font()
	var fs := int(h * (0.95 if text.length() < 2 else 0.8))
	var pos := Vector2(0, c.y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, maxi(4, fs / 5), Color(UiKit.INK, 0.85))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, color)
