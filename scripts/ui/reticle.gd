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
## Aiming down sights fades the hip reticle out as the sight comes up. Iron
## sights keep a small centre dot; an optic draws its own reticle on the point
## of aim (art/shaders/sight_lens.gdshader), so the dot goes too.
## Hit markers: an X that pops in and fades; white for a hit, pink for a kill,
## gold for a headshot (longer arms on a kill).

const COLORS := {
	"white": Color(1, 1, 1),
	"cyan": Color(0.35, 0.95, 1.0),
	"pink": Color(1.0, 0.45, 0.78),
	"green": Color(0.5, 1.0, 0.45),
	"yellow": Color(1.0, 0.88, 0.3),
}
const STYLES := ["auto", "cross", "circle", "bracket", "dot", "chevron"]
const HIT_LIFE := 0.26
## Hit-marker arm length in pixels at 1080p (the HUD canvas is 1920x1080).
const HIT_ARM := 30.0
const KILL_ARM := 36.0
const HIT_GAP := 12.0
const HEAD_COLOR := Color(1.0, 0.78, 0.18)
const DIAGONALS: Array[Vector2] = [Vector2(0.7071, 0.7071), Vector2(0.7071, -0.7071), Vector2(-0.7071, 0.7071), Vector2(-0.7071, -0.7071)]

## Spread cone radius in pixels (set by the HUD every frame).
var spread_px := 0.0
var style := "cross"
## 0-1: how far the player is aimed in. Reticles fade to a dot when aimed.
var aim := 0.0
var hit_time := 0.0
var hit_kill := false
var hit_head := false
var _shown_gap := 8.0
var _gap_lead := 8.0
var _player: Player


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_hit(killed: bool, headshot: bool) -> void:
	hit_time = HIT_LIFE
	hit_kill = killed
	hit_head = headshot
	queue_redraw()


func _process(delta: float) -> void:
	if hit_time > 0.0:
		hit_time = maxf(0.0, hit_time - delta)
	# Ease the gap so bloom reads as motion, not flicker: two easings in a row,
	# so even a sudden change (a shot, a rested precision weapon closing up)
	# starts and ends gently at any frame rate.
	var k := 1.0 - exp(-40.0 * delta)
	_gap_lead = lerpf(_gap_lead, maxf(spread_px, 6.0), k)
	_shown_gap = lerpf(_shown_gap, _gap_lead, k)
	queue_redraw()


func _color() -> Color:
	return COLORS.get(String(Settings.value("reticle_color")), Color.WHITE)


## True while the held weapon's sight draws its own reticle.
func _sight_has_reticle() -> bool:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	return _player != null and _player.view != null and _player.view.sight_has_reticle()


func _draw() -> void:
	var c := size * 0.5
	var col := _color()
	var outline := Color(0.08, 0.02, 0.14, 0.85)
	# The hip reticle is gone before the sight is fully up.
	var fade := 1.0 - smoothstep(0.0, 0.75, aim)
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
	# Centre dot: smaller when aimed (the sight does the work), and gone when
	# the sight has a reticle of its own.
	var dot_alpha := 1.0 - smoothstep(0.35, 0.85, aim) if _sight_has_reticle() else 1.0
	if dot_alpha > 0.01:
		var dot := lerpf(2.0, 1.5, aim)
		draw_circle(c, dot + 1.6, Color(outline, outline.a * dot_alpha))
		draw_circle(c, dot, Color(col, col.a * dot_alpha))

	if hit_time > 0.0:
		_draw_hit_marker(c, outline)


## The X: pops in oversized and settles over ~90 ms, drifts outwards, fades.
func _draw_hit_marker(c: Vector2, outline: Color) -> void:
	var age := HIT_LIFE - hit_time
	var a := clampf(hit_time / (HIT_LIFE * 0.6), 0.0, 1.0)
	var pop := lerpf(1.45, 1.0, ease(clampf(age / 0.09, 0.0, 1.0), 0.4))
	var hcol: Color = HEAD_COLOR if hit_head else (UiKit.PINK if hit_kill else Color.WHITE)
	hcol.a = a
	var inner := (HIT_GAP + age * 40.0) * pop
	var outer := inner + (KILL_ARM if hit_kill else HIT_ARM) * pop
	var width := 6.0 if hit_kill else 4.5
	for dir in DIAGONALS:
		draw_line(c + dir * (inner - 2.0), c + dir * (outer + 2.0), Color(outline, outline.a * a), width + 4.0)
		draw_line(c + dir * inner, c + dir * outer, hcol, width)
