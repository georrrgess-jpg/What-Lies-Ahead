class_name Reticle
extends Control
## Small centre reticle: four ticks that open with spread, plus a hit marker.

var spread := 0.0
var hit_time := 0.0
var hit_kill := false
var hit_head := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_hit(killed: bool, headshot: bool) -> void:
	hit_time = 0.22
	hit_kill = killed
	hit_head = headshot
	queue_redraw()


func _process(delta: float) -> void:
	if hit_time > 0.0:
		hit_time = maxf(0.0, hit_time - delta)
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var gap := 8.0 + spread * 5.0
	var length := 11.0
	var white := Color(1, 1, 1, 0.97)
	var outline := Color(0.08, 0.02, 0.14, 0.8)
	for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(c + dir * (gap - 1.5), c + dir * (gap + length + 1.5), outline, 6.5)
	for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(c + dir * gap, c + dir * (gap + length), white, 3.0)
	draw_circle(c, 3.4, outline)
	draw_circle(c, 2.0, white)
	if hit_time > 0.0:
		var a := clampf(hit_time / 0.22, 0.0, 1.0)
		var col := UiKit.PINK if hit_kill else (UiKit.AMBER if hit_head else Color.WHITE)
		col.a = a
		var inner := 9.0 + (1.0 - a) * 5.0
		var outer := inner + (13.0 if hit_kill else 9.0)
		for dir in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
			var n: Vector2 = dir.normalized()
			draw_line(c + n * inner, c + n * outer, col, 4.0 if hit_kill else 3.0)
