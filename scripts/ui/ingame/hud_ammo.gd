class_name HudAmmo
extends Control
## The HUD's ammo counter (lower right): the magazine in big digits, the
## reserve beside it, and a bar under both that shows the magazine and turns
## into the reload progress while reloading. The magazine kicks on every shot,
## turns amber when it runs low and red when it is empty.
##
## It draws itself and only redraws when a number changes, the kick settles
## or a reload is running.

const SIZE := Vector2(330, 132)
const MAG_SIZE := 100
const RESERVE_SIZE := 44
const BAR_HEIGHT := 10.0
## Magazine share at or under which the counter turns amber.
const LOW := 0.25

## The weapon colour of the bar.
var accent := UiKit.CYAN:
	set(v):
		accent = v
		queue_redraw()
## 0-1 while reloading, negative otherwise.
var reload := -1.0:
	set(v):
		if not is_equal_approx(v, reload):
			reload = v
			queue_redraw()

var _magazine := 0
var _capacity := 1
var _mag_text := "0"
var _reserve_text := "/ 0"
var _mag_width := 0.0
var _reserve_width := 0.0
var _kick := 0.0
var _back := StyleBoxFlat.new()
var _fill := StyleBoxFlat.new()


func _init() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back.bg_color = Color(UiKit.INK, 0.78)
	_back.set_corner_radius_all(5)
	_back.set_expand_margin_all(3)
	_fill.set_corner_radius_all(5)
	set_process(false)


## Sets the counter. `capacity` is the magazine size of the held weapon.
func set_ammo(magazine: int, reserve: int, capacity: int) -> void:
	var font := UiKit.display_font()
	if magazine < _magazine:
		_kick = 1.0
		set_process(true)
	_magazine = magazine
	_capacity = maxi(1, capacity)
	_mag_text = str(magazine)
	_reserve_text = "/ %d" % reserve
	_mag_width = font.get_string_size(_mag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, MAG_SIZE).x
	_reserve_width = font.get_string_size(_reserve_text, HORIZONTAL_ALIGNMENT_LEFT, -1, RESERVE_SIZE).x
	queue_redraw()


## Left edge of the digits, in this control's coordinates.
func digits_left() -> float:
	return size.x - _reserve_width - 14.0 - _mag_width


func _process(delta: float) -> void:
	_kick = maxf(0.0, _kick - delta * 9.0)
	queue_redraw()
	if _kick <= 0.0:
		set_process(false)


func _draw() -> void:
	var font := UiKit.display_font()
	var outline := Color(UiKit.INK, 0.9)
	var color := Color.WHITE
	if _magazine <= 0:
		color = UiKit.RED
	elif float(_magazine) / _capacity <= LOW:
		color = UiKit.AMBER
	var baseline := size.y - BAR_HEIGHT - 16.0
	var right := size.x
	# Reserve, then the magazine to its left (kicked up a little by each shot).
	var reserve_at := Vector2(right - _reserve_width, baseline)
	draw_string_outline(font, reserve_at, _reserve_text, HORIZONTAL_ALIGNMENT_LEFT, -1, RESERVE_SIZE, 10, outline)
	draw_string(font, reserve_at, _reserve_text, HORIZONTAL_ALIGNMENT_LEFT, -1, RESERVE_SIZE, UiKit.CREAM)
	var scale_k := 1.0 + 0.08 * _kick
	var mag_at := Vector2(right - _reserve_width - 14.0 - _mag_width * scale_k, baseline - 6.0 * _kick)
	draw_set_transform(mag_at, 0.0, Vector2(scale_k, scale_k))
	draw_string_outline(font, Vector2.ZERO, _mag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, MAG_SIZE, 16, outline)
	draw_string(font, Vector2.ZERO, _mag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, MAG_SIZE, color.lerp(Color.WHITE, _kick * 0.6))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Bar: the magazine, or the reload filling up.
	var bar := Rect2(size.x - 250.0, size.y - BAR_HEIGHT - 2.0, 250.0, BAR_HEIGHT)
	draw_style_box(_back, bar)
	var k := clampf(reload, 0.0, 1.0) if reload >= 0.0 else float(_magazine) / _capacity
	if k > 0.02:
		_fill.bg_color = Color.WHITE.lerp(accent, 0.35) if reload >= 0.0 else (color if _magazine <= 0 or color == UiKit.AMBER else accent)
		draw_style_box(_fill, Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y)))
