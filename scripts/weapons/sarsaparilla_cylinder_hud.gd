class_name SarsaparillaCylinderHud
extends Control
## The Sarsaparilla Six's round counter (made by its mode, under the HUD): a
## little cylinder below the crosshair with six chambers, so the rounds can be
## counted without looking down at the gun. A loaded chamber is an amber cap,
## a spent one a dark hollow ring; the sixth, the Last Call, is a cherry star.
## The next chamber to fire sits at the top, so the ring turns a sixth with
## every shot (eased). With one round left the star swells, pulses and
## "LAST CALL" shows under the ring. It fades out while aiming down the
## sights or during a reload and redraws only while it is shown.

const AMBER := Color(1.0, 0.647, 0.227)
const CREAM := Color(1.0, 0.957, 0.839)
const CHERRY := Color(1.0, 0.239, 0.431)
const DARK := Color(0.12, 0.08, 0.07, 0.75)
## Below the crosshair (pixels at 1080p; scaled with the screen height).
const OFFSET := Vector2(0.0, 62.0)
const RADIUS := 15.0
const CAP := 5.2
## Seconds the ring takes to turn to the next chamber.
const TURN_TIME := 0.09

var mode: SarsaparillaSixMode
var _time := 0.0
var _shown := 0.0
var _spent := 0
var _turn := 0.0
var _turn_from := 0.0
var _turn_t := 1.0
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font


func _process(delta: float) -> void:
	_time += delta
	var want := _wanted()
	var was := _shown
	_shown = move_toward(_shown, want, delta * 6.0)
	if _shown <= 0.0 and was <= 0.0:
		return
	var spent := _spent_now()
	if spent != _spent:
		_turn_from = _turn
		_turn_t = 0.0 if spent > _spent else 1.0
		_spent = spent
	_turn_t = minf(1.0, _turn_t + delta / TURN_TIME)
	var goal := -float(_spent) * TAU / mode.ROUNDS
	var k := 1.0 - pow(1.0 - _turn_t, 3.0)
	_turn = lerpf(_turn_from, goal, k) if _turn_t < 1.0 else goal
	queue_redraw()


## 0-1: how much the ring shows (faded out while aiming, reloading or away).
func _wanted() -> float:
	var w := mode.controller
	if w == null or w.current != mode.data or not w.enabled or not w.player.alive or w.is_reloading():
		return 0.0
	return clampf(1.0 - w.player.aim_blend * 1.6, 0.0, 1.0)


func _spent_now() -> int:
	var w := mode.controller
	if w == null or w.current != mode.data:
		return 0
	return clampi(mode.ROUNDS - w.magazine(), 0, mode.ROUNDS)


func _draw() -> void:
	if _shown <= 0.0:
		return
	var s := size.y / 1080.0
	var c := size * 0.5 + OFFSET * s
	var r := RADIUS * s
	var a := _shown
	var last := _spent == mode.ROUNDS - 1
	var beat := 0.5 + 0.5 * sin(_time * 10.0)
	draw_circle(c, r + CAP * s * 1.6, Color(DARK, DARK.a * a))
	draw_arc(c, r + CAP * s * 1.6, 0.0, TAU, 40, Color(AMBER, 0.55 * a), 1.4 * s, true)
	for i in mode.ROUNDS:
		# Chamber i sits at the top once i rounds are spent; the next one is always on top.
		var ang := -PI * 0.5 + float(i) * TAU / mode.ROUNDS + _turn
		var p := c + Vector2(cos(ang), sin(ang)) * r
		var loaded := i >= _spent
		var star := i == mode.ROUNDS - 1
		if not loaded:
			draw_arc(p, CAP * s * 0.8, 0.0, TAU, 14, Color(CREAM, 0.35 * a), 1.2 * s, true)
			continue
		if star:
			var big := (1.35 + 0.35 * beat) if last else 1.0
			_draw_star(p, CAP * s * 1.25 * big, Color(CHERRY, a))
			if last:
				draw_arc(p, CAP * s * (2.0 + beat * 0.6), 0.0, TAU, 20, Color(CHERRY, (0.8 - 0.5 * beat) * a), 1.6 * s, true)
		else:
			draw_circle(p, CAP * s, Color(AMBER, a))
			draw_arc(p, CAP * s, 0.0, TAU, 14, Color(CREAM, 0.9 * a), 1.0 * s, true)
	if last and _font:
		var text := "LAST CALL"
		var fs := int(15 * s)
		var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		var at := c + Vector2(-w * 0.5, r + CAP * s * 2.0 + fs * 1.1)
		draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(4 * s), Color(DARK, 0.9 * a))
		draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(CHERRY.lerp(CREAM, beat * 0.35), a))


func _draw_star(p: Vector2, radius: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var ang := -PI * 0.5 + float(k) * TAU / 10.0
		var rr := radius if k % 2 == 0 else radius * 0.45
		pts.append(p + Vector2(cos(ang), sin(ang)) * rr)
	draw_colored_polygon(pts, color)
	pts.append(pts[0])
	draw_polyline(pts, Color(CREAM, color.a), 1.0, true)
