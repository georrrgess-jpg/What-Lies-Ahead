class_name GuidePortrait
extends Control
## BOLT, the Boot Camp barker-bot, drawn in code: a tin head with a dented top
## hat, big cyan eyes and a speaker-grille mouth that flaps while he talks.
## Redraws only while talking (a 10 Hz timer) or when the mood changes.

const TIN := Color("2b918c")
const TIN_DARK := Color("17605d")
const HAT := Color("d8265f")
const HAT_BAND := Color("ffc24a")
const EYE := Color("35f0ff")
const INK := Color("120c2e")
const CREAM := Color("fff3dc")

var talking := false:
	set(v):
		talking = v
		if _timer:
			_timer.paused = not v
		_open = false
		queue_redraw()
var _open := false
var _blink := false
var _timer: Timer


func _ready() -> void:
	custom_minimum_size = Vector2(120, 132)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timer = Timer.new()
	_timer.wait_time = 0.1
	_timer.autostart = true
	_timer.paused = not talking
	_timer.timeout.connect(_flap)
	add_child(_timer)


func _flap() -> void:
	_open = not _open if randf() < 0.8 else _open
	_blink = randf() < 0.04
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var c := Vector2(w * 0.5, h * 0.6)
	var head := Rect2(c - Vector2(w * 0.36, h * 0.27), Vector2(w * 0.72, h * 0.54))
	# Antenna with a bulb, ears, head.
	draw_line(Vector2(c.x + w * 0.22, head.position.y), Vector2(c.x + w * 0.3, head.position.y - h * 0.2), INK, 4.0)
	draw_circle(Vector2(c.x + w * 0.3, head.position.y - h * 0.2), 6.0, HAT_BAND)
	for side in [-1.0, 1.0]:
		draw_rect(Rect2(Vector2(c.x + side * w * 0.36 - (8.0 if side > 0 else 0.0) - (0.0 if side > 0 else 0.0), c.y - 14.0), Vector2(8.0, 28.0)), TIN_DARK)
	_round_rect(head.grow(3.0), INK, 18.0)
	_round_rect(head, TIN, 16.0)
	_round_rect(Rect2(head.position + Vector2(6, head.size.y * 0.55), Vector2(head.size.x - 12, head.size.y * 0.4)), TIN_DARK, 10.0)
	# Eyes.
	for side in [-1.0, 1.0]:
		var e := Vector2(c.x + side * w * 0.15, c.y - h * 0.06)
		draw_circle(e, w * 0.11, INK)
		if _blink:
			draw_rect(Rect2(e - Vector2(w * 0.08, 2.0), Vector2(w * 0.16, 4.0)), EYE)
		else:
			draw_circle(e, w * 0.085, EYE)
			draw_circle(e + Vector2(-w * 0.03, -w * 0.03), w * 0.025, CREAM)
	# Grille mouth.
	var mouth_h := h * (0.12 if _open else 0.05)
	var m := Rect2(Vector2(c.x - w * 0.17, c.y + h * 0.11), Vector2(w * 0.34, mouth_h))
	_round_rect(m.grow(2.0), INK, 5.0)
	draw_rect(m, Color("ff3fa4") if _open else CREAM)
	for i in 4:
		var x := m.position.x + m.size.x * (i + 1) / 5.0
		draw_line(Vector2(x, m.position.y), Vector2(x, m.end.y), INK, 2.0)
	# Top hat, tilted a little.
	var brim_y := head.position.y + 4.0
	draw_set_transform(Vector2(c.x, brim_y), -0.12, Vector2.ONE)
	_round_rect(Rect2(Vector2(-w * 0.32, -8.0), Vector2(w * 0.64, 12.0)), INK, 5.0)
	_round_rect(Rect2(Vector2(-w * 0.3, -7.0), Vector2(w * 0.6, 9.0)), HAT, 4.0)
	_round_rect(Rect2(Vector2(-w * 0.19, -h * 0.3), Vector2(w * 0.38, h * 0.3 - 4.0)), INK, 6.0)
	_round_rect(Rect2(Vector2(-w * 0.17, -h * 0.29), Vector2(w * 0.34, h * 0.29 - 6.0)), HAT, 5.0)
	draw_rect(Rect2(Vector2(-w * 0.17, -h * 0.11), Vector2(w * 0.34, h * 0.06)), HAT_BAND)
	draw_set_transform(Vector2.ZERO)


func _round_rect(r: Rect2, color: Color, radius: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(radius))
	draw_style_box(sb, r)
