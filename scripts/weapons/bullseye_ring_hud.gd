class_name BullseyeRingHud
extends Control
## The Bullseye Longbow's draw ring (made by its mode, under the HUD): while
## the bow draws, a ring closes in round the crosshair. At full draw, for
## the Bullseye window, it locks tight in gold with four pips and pulses (a
## release now is a Bullseye); past the window it reddens and wobbles out
## with the arm's fatigue. A loosed Bullseye flashes the ring outwards. It
## redraws only while it is shown.

const GOLD := Color(1.0, 0.82, 0.25)
const CREAM := Color(1.0, 0.96, 0.86)
const TIRED := Color(1.0, 0.36, 0.3)
const SHADOW := Color(0.08, 0.04, 0.03, 0.55)
## Ring radius (pixels at 1080p) as the draw starts and at full draw.
const OPEN_RADIUS := 64.0
const TIGHT_RADIUS := 17.0
## Seconds the outward flash of a loosed Bullseye lasts.
const FLASH_TIME := 0.32

var mode: BullseyeBowMode
var _time := 0.0
var _shown := 0.0
var _flash := 0.0
var _seen := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_time += delta
	var w := mode.controller
	var held := w != null and w.current == mode.data and w.enabled and w.player.alive
	var draw := w.shown_charge() if held else 0.0
	# A loosed Bullseye flashes the ring outwards.
	if mode.bullseyes != _seen:
		_seen = mode.bullseyes
		_flash = FLASH_TIME
	var want := 1.0 if draw > 0.02 else 0.0
	var was := _shown
	_shown = move_toward(_shown, want, delta * (8.0 if want > 0.0 else 5.0))
	_flash = maxf(0.0, _flash - delta)
	if _shown <= 0.0 and was <= 0.0 and _flash <= 0.0:
		return
	queue_redraw()


func _draw() -> void:
	var w := mode.controller
	if w == null:
		return
	var s := size.y / 1080.0
	var c := size * 0.5
	if _flash > 0.0:
		var k := 1.0 - _flash / FLASH_TIME
		draw_arc(c, (TIGHT_RADIUS + 70.0 * k) * s, 0.0, TAU, 48, Color(GOLD, 1.0 - k), (5.0 - 3.0 * k) * s, true)
	if _shown <= 0.0:
		return
	var draw := w.shown_charge() if w.current == mode.data else 0.0
	var a := _shown
	var eased := 1.0 - pow(1.0 - draw, 2.2)
	var r := lerpf(OPEN_RADIUS, TIGHT_RADIUS, eased) * s
	var tired := mode.fatigue()
	if mode.in_window():
		var beat := 0.5 + 0.5 * sin(_time * 26.0)
		draw_arc(c, r, 0.0, TAU, 48, Color(SHADOW, SHADOW.a * a), 7.0 * s, true)
		draw_arc(c, r, 0.0, TAU, 48, Color(GOLD, a), (3.0 + 1.2 * beat) * s, true)
		draw_arc(c, r + 7.0 * s, 0.0, TAU, 48, Color(GOLD, (0.35 + 0.3 * beat) * a), 1.4 * s, true)
		for i in 4:
			var ang := PI * 0.25 + i * PI * 0.5
			var d := Vector2(cos(ang), sin(ang))
			draw_line(c + d * (r + 4.0 * s), c + d * (r + 13.0 * s), Color(GOLD, a), 3.0 * s, true)
		return
	if tired > 0.0:
		# Fatigue: the ring loosens, reddens and shakes with the arm.
		var k := clampf(tired / 1.5, 0.0, 1.0)
		var shake := Vector2(sin(_time * 47.0), sin(_time * 39.0 + 1.3)) * (1.0 + 3.0 * k) * s
		var rr := r + (6.0 + 26.0 * k) * s
		var col := CREAM.lerp(TIRED, 0.4 + 0.6 * k)
		draw_arc(c + shake, rr, 0.0, TAU, 40, Color(SHADOW, SHADOW.a * a), 5.0 * s, true)
		for i in 4:
			var start := i * PI * 0.5 + PI * 0.08
			draw_arc(c + shake, rr, start, start + PI * 0.34, 10, Color(col, a * 0.9), 2.2 * s, true)
		return
	# Drawing: a cream ring closing in, brighter as it nears full draw.
	draw_arc(c, r, 0.0, TAU, 48, Color(SHADOW, SHADOW.a * a), 5.0 * s, true)
	draw_arc(c, r, 0.0, TAU * draw, 48, Color(CREAM.lerp(GOLD, draw * draw), a * (0.55 + 0.45 * draw)), 2.4 * s, true)
