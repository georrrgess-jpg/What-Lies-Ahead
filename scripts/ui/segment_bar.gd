class_name SegmentBar
extends Control
## The HUD's health bar: a heart, the health number and five chunky slanted
## cells. Damage leaves a pale chunk that drains away a moment later, healing
## fills smoothly, and at a quarter health or less the bar turns red and
## beats. An overshield lies over the cells as a slim cyan strip (damage eats
## that first); it sweeps in when bought and flashes when it soaks a hit.
##
## Nothing runs or redraws while the bar is at rest.

const SHIELD_COLOR := Color(0.35, 0.93, 1.0)
## Health fraction at or under which the bar is in its low state.
const LOW := 0.25
const NUMBER_WIDTH := 118.0
const CELL_TOP := 22.0
const SHIELD_TOP := 6.0
const SHIELD_HEIGHT := 10.0
const SKEW := 12.0
const GHOST_DELAY := 0.35

@export var segments := 5
@export var gap := 7.0

## Health as a fraction of the maximum.
var value := 1.0: set = set_value
## Health points at a full bar (for the number).
var max_points := 100.0
## 1 right after a hit; fades by itself.
var flash := 0.0:
	set(v):
		flash = v
		_wake()
## Overshield, as a fraction of maximum health (0.5 covers half the cells).
var shield := 0.0: set = set_shield
var shield_flash := 0.0:
	set(v):
		shield_flash = v
		_wake()

var _shown := 1.0
var _ghost := 1.0
var _ghost_wait := 0.0
var _shield_shown := 0.0
var _time := 0.0
var _text := "100"
var _quad := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func set_value(v: float) -> void:
	var next := clampf(v, 0.0, 1.0)
	if next < value:
		# Damage: the bar drops at once and the lost chunk lingers.
		_ghost = maxf(_ghost, _shown)
		_shown = next
		_ghost_wait = GHOST_DELAY
	value = next
	_text = str(int(ceil(value * max_points)))
	_wake()


func set_shield(v: float) -> void:
	shield = maxf(0.0, v)
	_wake()


func _wake() -> void:
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	flash = maxf(0.0, flash - delta * 3.0)
	shield_flash = maxf(0.0, shield_flash - delta * 3.0)
	_shown = move_toward(_shown, value, delta * 1.6)
	_shield_shown = move_toward(_shield_shown, shield, delta * 2.2)
	_ghost_wait = maxf(0.0, _ghost_wait - delta)
	if _ghost_wait <= 0.0:
		_ghost = move_toward(_ghost, _shown, delta * 1.2)
	var low := value > 0.0 and value <= LOW
	var busy := flash > 0.0 or shield_flash > 0.0 or low or _ghost > _shown \
		or not is_equal_approx(_shown, value) or not is_equal_approx(_shield_shown, shield)
	queue_redraw()
	if not busy:
		_ghost = _shown
		set_process(false)


func _draw() -> void:
	var low := value > 0.0 and value <= LOW
	var beat := 0.5 + 0.5 * sin(_time * 9.0) if low else 0.0
	var color := UiKit.GREEN
	if value <= LOW:
		color = UiKit.RED
	elif value <= 0.5:
		color = UiKit.AMBER
	color = color.lerp(Color.WHITE, maxf(flash, beat * 0.25))
	var left := NUMBER_WIDTH
	var bottom := size.y
	var cells_w := size.x - left - SKEW
	var w := (cells_w - gap * (segments - 1)) / segments
	# Backing plate: dark, with a red rim that beats in the low state.
	_set_quad(left - 8.0, left + cells_w + 8.0, CELL_TOP - 7.0, bottom + 7.0, bottom)
	draw_colored_polygon(_quad, Color(UiKit.RED.darkened(0.55), 0.55 + 0.3 * beat) if low else Color(UiKit.INK, 0.72))
	for i in segments:
		var x := left + i * (w + gap)
		_set_quad(x, x + w, CELL_TOP, bottom, bottom)
		draw_colored_polygon(_quad, Color(0.09, 0.07, 0.17, 0.92))
		var fill := clampf(_shown * segments - i, 0.0, 1.0)
		var ghost := clampf(_ghost * segments - i, 0.0, 1.0)
		if (ghost - fill) * w >= 1.0:
			_set_quad(x + w * fill, x + w * ghost, CELL_TOP, bottom, bottom)
			draw_colored_polygon(_quad, Color(1.0, 0.94, 0.86, 0.9))
		if fill * w >= 1.0:
			_set_quad(x, x + w * fill, CELL_TOP, bottom, bottom)
			draw_colored_polygon(_quad, color)
			_set_quad(x, x + w * fill, CELL_TOP, CELL_TOP + 9.0, bottom)
			draw_colored_polygon(_quad, color.lightened(0.42))
			_set_quad(x, x + w * fill, bottom - 6.0, bottom, bottom)
			draw_colored_polygon(_quad, color.darkened(0.28))
	_draw_shield(left, cells_w, bottom)
	_draw_number(color, low, beat)


## The overshield: a slim strip over the cells, as long as its share of health.
func _draw_shield(left: float, cells_w: float, bottom: float) -> void:
	var right := left + cells_w * minf(_shield_shown, 1.0)
	if right - left < 1.0:
		return
	var top := SHIELD_TOP
	_set_quad(left - 4.0, right + 4.0, top - 4.0, top + SHIELD_HEIGHT + 4.0, bottom)
	draw_colored_polygon(_quad, Color(UiKit.INK, 0.8))
	_set_quad(left, right, top, top + SHIELD_HEIGHT, bottom)
	draw_colored_polygon(_quad, SHIELD_COLOR.lerp(Color.WHITE, shield_flash))
	_set_quad(left, right, top, top + 3.0, bottom)
	draw_colored_polygon(_quad, Color(1, 1, 1, 0.55))


func _draw_number(color: Color, low: bool, beat: float) -> void:
	var font := UiKit.display_font()
	var icon := 34.0 + (5.0 * beat if low else 0.0)
	HudIcon.paint(self, &"heart", Vector2(22.0, size.y - 22.0), icon + 8.0, Color(UiKit.INK, 0.85))
	HudIcon.paint(self, &"heart", Vector2(22.0, size.y - 22.0), icon, UiKit.RED if value <= 0.5 else color)
	var at := Vector2(44.0, size.y - 6.0)
	draw_string_outline(font, at, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, 10, Color(UiKit.INK, 0.9))
	draw_string(font, at, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color.WHITE if not low else color.lightened(0.3))


## Puts a slanted quad into _quad: columns x0..x1 at rows y0..y1, leaning
## right by SKEW over the height of the cells (measured up from `bottom`).
func _set_quad(x0: float, x1: float, y0: float, y1: float, bottom: float) -> void:
	var lean := SKEW / (bottom - CELL_TOP)
	var k0 := (bottom - y0) * lean
	var k1 := (bottom - y1) * lean
	_quad[0] = Vector2(x0 + k0, y0)
	_quad[1] = Vector2(x1 + k0, y0)
	_quad[2] = Vector2(x1 + k1, y1)
	_quad[3] = Vector2(x0 + k1, y1)
