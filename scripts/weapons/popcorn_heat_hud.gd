class_name PopcornHeatHud
extends Control
## The Popcorn Popper's heat gauge (made by its mode, under the HUD): a
## curved bar under the crosshair in three zones (cold, warm, hot) that
## fills with the kettle's heat, a tick at the jam line, and a word off its
## jam end that pops when the stage changes ("POP!", "BUTTER!"). Jammed, the
## bar flashes red, drains with the jam and "JAMMED!" shakes beside it. It fades out once
## the kettle is cold and redraws only while it shows.

const RADIUS := 58.0
## The arc spans this many radians, centred under the crosshair.
const SPAN := 1.6
const WIDTH := 7.0
const COLD := Color(0.45, 0.85, 1.0)
const WARM := Color(1.0, 0.92, 0.55)
const HOT := Color(1.0, 0.5, 0.16)
const JAM := Color(1.0, 0.22, 0.22)
const WORD_TIME := 0.7

var mode: PopcornPopperMode
var _time := 0.0
var _shown := 0.0
var _stage := PopcornPopperMode.Stage.COLD
var _word := ""
var _word_left := 0.0
var _word_color := WARM


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_time += delta
	var active := _active()
	var want := 1.0 if active and (mode.heat > 0.01 or mode.jam > 0.0) else 0.0
	var was := _shown
	_shown = move_toward(_shown, want, delta * (6.0 if want > _shown else 2.0))
	_watch_stage(active)
	_word_left = maxf(0.0, _word_left - delta)
	if _shown > 0.0 or was > 0.0:
		queue_redraw()


func _active() -> bool:
	var w := mode.controller
	return w != null and w.current == mode.data and w.enabled and w.player.alive


## A word pops when the kettle climbs into the next stage, or jams.
func _watch_stage(active: bool) -> void:
	var stage := mode.stage()
	if active and stage > _stage and mode.jam <= 0.0:
		_word = "POP!" if stage == PopcornPopperMode.Stage.WARM else "BUTTER!"
		_word_color = WARM if stage == PopcornPopperMode.Stage.WARM else HOT
		_word_left = WORD_TIME
	_stage = stage


func _draw() -> void:
	if _shown <= 0.0:
		return
	var c := size * 0.5
	var a := _shown
	var start := PI * 0.5 + SPAN * 0.5
	var jammed := mode.jam > 0.0
	# Backing: an ink groove with the three zones faintly lit.
	draw_arc(c, RADIUS, start - SPAN, start, 48, Color(UiKit.INK, 0.65 * a), WIDTH + 5.0, true)
	_zone(c, 0.0, PopcornPopperMode.WARM_AT, COLD, 0.22 * a)
	_zone(c, PopcornPopperMode.WARM_AT, PopcornPopperMode.HOT_AT, WARM, 0.22 * a)
	_zone(c, PopcornPopperMode.HOT_AT, 1.0, HOT, 0.22 * a)
	var fill := mode.heat
	var col := _color(fill)
	if jammed:
		fill = mode.jam / PopcornPopperMode.JAM_TIME
		col = JAM.lerp(Color.WHITE, 0.5 + 0.5 * sin(_time * 22.0))
	_zone(c, 0.0, fill, col, a)
	# The needle at the heat, and the jam line at the far end.
	var tip := start - SPAN * mode.heat
	var dir := Vector2(cos(tip), sin(tip))
	draw_line(c + dir * (RADIUS - 9.0), c + dir * (RADIUS + 9.0), Color(UiKit.INK, a), 5.0, true)
	draw_line(c + dir * (RADIUS - 8.0), c + dir * (RADIUS + 8.0), Color(Color.WHITE, a), 2.2, true)
	var end := Vector2(cos(start - SPAN), sin(start - SPAN))
	draw_line(c + end * (RADIUS - 7.0), c + end * (RADIUS + 7.0), Color(JAM, a), 3.0, true)
	# Words sit off the jam end of the bar, clear of the reload prompt under the crosshair.
	var word_at := c + end * RADIUS + Vector2(14.0, 8.0)
	if jammed:
		var shake := Vector2(sin(_time * 61.0), cos(_time * 47.0)) * 2.0
		_text(word_at + shake, "JAMMED!", JAM, 22, a)
	elif _word_left > 0.0:
		var u := 1.0 - _word_left / WORD_TIME
		_text(word_at + Vector2(0.0, -8.0 * u), _word, _word_color, int(18.0 + 6.0 * sin(PI * minf(1.0, u * 3.0))), a * minf(1.0, _word_left * 4.0))


func _zone(c: Vector2, from: float, to: float, col: Color, alpha: float) -> void:
	if to <= from:
		return
	var start := PI * 0.5 + SPAN * 0.5
	draw_arc(c, RADIUS, start - SPAN * from, start - SPAN * to, maxi(4, int(48 * (to - from))), Color(col, col.a * alpha), WIDTH, true)


static func _color(h: float) -> Color:
	return COLD.lerp(WARM, smoothstep(PopcornPopperMode.WARM_AT - 0.06, PopcornPopperMode.WARM_AT, h)).lerp(HOT, smoothstep(PopcornPopperMode.HOT_AT - 0.06, PopcornPopperMode.HOT_AT, h))


## `text` starting at `at` (its baseline's left end).
func _text(at: Vector2, text: String, col: Color, font_size: int, alpha: float) -> void:
	var font := get_theme_default_font()
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color(UiKit.INK, 0.9 * alpha))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(col, alpha))
