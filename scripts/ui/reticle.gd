class_name Reticle
extends Control
## Centre reticle. The gap is drawn from the weapon's real spread cone, so what
## you see is where the shot can land. Styles:
##   cross    four ticks (pistol)
##   circle   ring + centre dot (carbine)
##   bracket  left/right arcs framing the pellet cone (scatter)
##   dot      centre dot only
##   chevron  a small inverted V with a dot (precision)
## The style comes from the weapon unless Settings "reticle_style" overrides it.
## Hit markers: white for a hit, amber for a headshot, pink X for a kill.

const COLORS := {
	"white": Color(1, 1, 1),
	"cyan": Color(0.35, 0.95, 1.0),
	"pink": Color(1.0, 0.45, 0.78),
	"green": Color(0.5, 1.0, 0.45),
	"yellow": Color(1.0, 0.88, 0.3),
}
const STYLES := ["auto", "cross", "circle", "bracket", "dot", "chevron"]

## Spread cone radius in pixels (set by the HUD every frame).
var spread_px := 0.0
var style := "cross"
## 0-1: how far the player is aimed in. Reticles fade to a dot when aimed.
var aim := 0.0
var hit_time := 0.0
var hit_kill := false
var hit_head := false
var _shown_gap := 8.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_hit(killed: bool, headshot: bool) -> void:
	hit_time = 0.24
	hit_kill = killed
	hit_head = headshot
	queue_redraw()


func _process(delta: float) -> void:
	if hit_time > 0.0:
		hit_time = maxf(0.0, hit_time - delta)
	# Ease the gap so bloom reads as motion, not flicker.
	_shown_gap = lerpf(_shown_gap, maxf(spread_px, 6.0), 1.0 - exp(-22.0 * delta))
	queue_redraw()


func _color() -> Color:
	return COLORS.get(String(Settings.value("reticle_color")), Color.WHITE)


func _draw() -> void:
	var c := size * 0.5
	var col := _color()
	var outline := Color(0.08, 0.02, 0.14, 0.85)
	var fade := 1.0 - aim
	var gap := _shown_gap
	col.a = 0.97

	match style:
		"dot":
			pass
		"circle":
			if fade > 0.01:
				var r := maxf(gap, 11.0)
				draw_arc(c, r, 0, TAU, 48, Color(outline, outline.a * fade), 5.0, true)
				draw_arc(c, r, 0, TAU, 48, Color(col, col.a * fade), 2.2, true)
		"bracket":
			if fade > 0.01:
				var r := maxf(gap, 16.0)
				for side in [-1.0, 1.0]:
					var mid := 0.0 if side > 0 else PI
					draw_arc(c, r, mid - 0.55, mid + 0.55, 18, Color(outline, outline.a * fade), 6.0, true)
					draw_arc(c, r, mid - 0.55, mid + 0.55, 18, Color(col, col.a * fade), 2.8, true)
		"chevron":
			if fade > 0.01:
				var pts := PackedVector2Array([c + Vector2(-9, 13 + gap * 0.3), c + Vector2(0, 5 + gap * 0.3), c + Vector2(9, 13 + gap * 0.3)])
				draw_polyline(pts, Color(outline, outline.a * fade), 6.0, true)
				draw_polyline(pts, Color(col, col.a * fade), 2.6, true)
		_:
			if fade > 0.01:
				var length := 11.0
				for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
					draw_line(c + dir * (gap - 1.5), c + dir * (gap + length + 1.5), Color(outline, outline.a * fade), 6.5)
				for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
					draw_line(c + dir * gap, c + dir * (gap + length), Color(col, col.a * fade), 3.0)
	# Centre dot is always there (smaller when aimed: the sight does the work).
	var dot := lerpf(2.0, 1.5, aim)
	draw_circle(c, dot + 1.6, outline)
	draw_circle(c, dot, col)

	if hit_time > 0.0:
		var a := clampf(hit_time / 0.24, 0.0, 1.0)
		var hcol := UiKit.PINK if hit_kill else (UiKit.AMBER if hit_head else Color.WHITE)
		hcol.a = a
		var inner := 10.0 + (1.0 - a) * 6.0
		var outer := inner + (15.0 if hit_kill else (12.0 if hit_head else 9.0))
		for dir in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
			var n: Vector2 = dir.normalized()
			draw_line(c + n * (inner - 1), c + n * (outer + 1), Color(outline, outline.a * a), 7.0 if hit_kill else 6.0)
			draw_line(c + n * inner, c + n * outer, hcol, 4.0 if hit_kill else 3.0)
