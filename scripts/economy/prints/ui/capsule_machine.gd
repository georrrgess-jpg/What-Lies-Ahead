class_name CapsuleMachine
extends Control
## The Prize Capsule machine (approved concept media/concepts/c1_capsules.png),
## drawn and animated at any size: a marquee sign with chasing bulbs, a glass
## globe of two-tone capsules that bob and churn, a gold crank, the coin slot
## with the capsule count, and the chute a capsule rattles down into. Every
## measure scales with the control, so the same machine is the star of the
## Capsules tab and fills the screen in the opening.
##
##   machine.turn(rarity_colour, true)   # heavy: wind back, a full weighted turn
##   machine.turned.connect(...)          # the capsule sits in the chute

signal turned

const CAPSULES := 22
const BODY := Color("e8417e")
const BODY_DARK := Color("a8205a")
const GOLD := Color("ffc24a")
const GLASS := Color(0.55, 0.78, 1.0, 0.13)
const CREAM := Color("fff3dc")
const CAPSULE_COLORS := [Color("8fe3ff"), Color("ff6fb5"), Color("ffd35c"), Color("b98cff"), Color("7dffa8"), Color("ff9a5c")]
## The design size every measure is drawn at (then scaled to fit).
const DESIGN := Vector2(440, 560)
## Where the chute is, in the design space.
const CHUTE := Rect2(250, 444, 110, 80)

## The sign: "SERIES 1" over the series name.
var series_text := "SERIES 1"
var series_name := ""
## How many capsules the player has (drawn in the coin window).
var capsule_count := 0
## 0-1: how hard the globe churns (the crank sets it).
var churn := 0.0
var _time := 0.0
var _crank := 0.0
var _drop := -1.0
var _drop_color := CREAM
var _chute_glow := 0.0
var _seeds: Array[Vector3] = []
var _clicks := 0
var _turn: Tween
var _body_box: StyleBoxFlat
var _plate_box: StyleBoxFlat
var _slot_box: StyleBoxFlat
var _chute_box: StyleBoxFlat
var _foot_box: StyleBoxFlat
## The top half of a unit circle, built once (drawn scaled per capsule).
static var _half: PackedVector2Array


func _init() -> void:
	custom_minimum_size = Vector2(330, 420)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for i in CAPSULES:
		_seeds.append(Vector3(rng.randf(), rng.randf(), rng.randf()))
	_body_box = _flat(BODY, BODY_DARK, 26, 6)
	_body_box.shadow_color = Color(0, 0, 0, 0.35)
	_body_box.shadow_size = 14
	_plate_box = _flat(Color("8f1d3f"), GOLD, 14, 4)
	_slot_box = _flat(UiKit.NAVY, GOLD, 8, 3)
	_chute_box = _flat(UiKit.INK, GOLD, 12, 4)
	_foot_box = _flat(BODY_DARK.darkened(0.25), BODY_DARK.darkened(0.45), 12, 3)
	if _half.is_empty():
		for k in 17:
			var a := PI + PI * k / 16.0
			_half.append(Vector2(cos(a), sin(a)))


static func _flat(fill: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = border
	b.set_corner_radius_all(radius)
	b.set_border_width_all(width)
	b.anti_aliasing = true
	return b


func _process(delta: float) -> void:
	_time += delta
	if is_visible_in_tree():
		queue_redraw()


## Turns the crank, churns the globe and drops a capsule of `color` down the
## chute; emits `turned` when it lands. `heavy` winds the crank back first and
## gives it a full, weighted turn (the opening); otherwise a quick turn.
func turn(color: Color, heavy := false) -> void:
	_drop_color = color
	_clicks = 0
	_drop = -1.0
	_chute_glow = 0.0
	if _turn:
		_turn.kill()
	_turn = create_tween()
	if heavy:
		_turn.tween_method(_set_crank, 0.0, -0.45, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_turn.tween_method(_set_crank, -0.45, TAU, 1.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		_turn.parallel().tween_property(self, "churn", 1.0, 0.6).set_delay(0.2)
	else:
		_turn.tween_method(_set_crank, 0.0, TAU, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_turn.parallel().tween_property(self, "churn", 1.0, 0.3)
	_turn.tween_callback(Sfx.play.bind(&"prz_rattle", -4.0))
	_turn.tween_property(self, "_drop", 1.0, 0.5).from(0.0).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_turn.parallel().tween_property(self, "churn", 0.0, 0.7)
	_turn.parallel().tween_property(self, "_chute_glow", 1.0, 0.5)
	_turn.tween_callback(func(): _crank = 0.0)
	_turn.tween_callback(turned.emit)


## Hides the dropped capsule (the reveal has taken it) and stops a turn.
func take_capsule() -> void:
	if _turn:
		_turn.kill()
	_drop = -1.0
	_chute_glow = 0.0
	churn = 0.0
	_crank = 0.0


## Where the capsule in the chute is, in this control's space.
func chute_point() -> Vector2:
	return _chute_rect().get_center()


## The capsule's radius in the chute, in this control's space.
func chute_capsule_radius() -> float:
	return _chute_rect().size.x * 0.3


func _set_crank(a: float) -> void:
	_crank = a
	var click := int(maxf(a, 0.0) / (TAU / 6.0))
	if click > _clicks:
		_clicks = click
		Sfx.play(&"prz_crank", -8.0, 0.9 + 0.04 * click)


## The scale that fits the design into the control (drawn centred).
func _scale() -> float:
	var k := minf(size.x / DESIGN.x, size.y / DESIGN.y)
	return k


func _origin(k: float) -> Vector2:
	return (size - DESIGN * k) * 0.5


func _chute_rect() -> Rect2:
	var k := _scale()
	var o := _origin(k)
	return Rect2(o + CHUTE.position * k, CHUTE.size * k)


func _draw() -> void:
	var k := _scale()
	var o := _origin(k)
	draw_set_transform(o, 0.0, Vector2(k, k))
	var c := Vector2(220, 236)
	var r := 140.0
	draw_style_box(_foot_box, Rect2(70, 526, 300, 32))
	# The globe: a gold rim, the glass, the capsules inside and highlights.
	draw_circle(c, r + 12.0, GOLD.darkened(0.25))
	draw_circle(c, r + 5.0, GOLD)
	draw_circle(c, r, UiKit.NAVY)
	_draw_capsules(c, r)
	draw_circle(c, r, GLASS)
	draw_arc(c - Vector2(r * 0.2, r * 0.22), r * 0.7, PI * 1.05, PI * 1.45, 24, Color(1, 1, 1, 0.45), 11.0, true)
	draw_arc(c + Vector2(r * 0.3, r * 0.25), r * 0.62, PI * 0.1, PI * 0.28, 12, Color(1, 1, 1, 0.22), 6.0, true)
	# The body in front of the globe's foot, with a gold collar and a shine.
	draw_style_box(_body_box, Rect2(48, 364, 344, 176))
	draw_rect(Rect2(140, 356, 160, 18), GOLD.darkened(0.2))
	draw_rect(Rect2(70, 378, 300, 7), Color(1, 1, 1, 0.18))
	_draw_sign(Vector2(220, 46))
	_draw_crank(Vector2(126, 446), 50.0)
	_draw_slot(Rect2(250, 400, 110, 36))
	_draw_chute(CHUTE)
	var font := UiKit.display_font()
	draw_string(font, Vector2(66, 528), "TURN!", HORIZONTAL_ALIGNMENT_CENTER, 120.0, 26, CREAM)
	draw_set_transform(Vector2.ZERO)


func _draw_sign(at: Vector2) -> void:
	var font := UiKit.display_font()
	var rect := Rect2(at.x - 150.0, at.y - 40.0, 300.0, 78.0)
	draw_style_box(_plate_box, rect)
	var bulbs := 15
	for i in bulbs:
		var x := rect.position.x + rect.size.x * (i + 0.5) / bulbs
		var lit := int(_time * 6.0 + i) % 3 == 0
		draw_circle(Vector2(x, rect.position.y - 1.0), 4.5, CREAM if lit else GOLD.darkened(0.3))
		draw_circle(Vector2(x, rect.end.y + 1.0), 4.5, CREAM if not lit else GOLD.darkened(0.3))
	draw_string(font, Vector2(rect.position.x, rect.position.y + 40.0), series_text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 34, CREAM)
	draw_string(font, Vector2(rect.position.x, rect.position.y + 66.0), series_name, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 20, GOLD)


## The capsules heaped in the globe: they settle at the bottom and bob; the
## crank churns them round and tosses them up.
func _draw_capsules(c: Vector2, r: float) -> void:
	var cr := r * 0.17
	for i in CAPSULES:
		var s := _seeds[i]
		var row := i / 6
		var col := i % 6
		var rest := Vector2((col - 2.5) * cr * 1.7 + (row % 2) * cr * 0.55, r * 0.68 - row * cr * 1.5)
		rest.x += (s.x - 0.5) * cr * 0.5
		var bob := Vector2(sin(_time * (1.2 + s.y) + s.z * 9.0), cos(_time * (1.0 + s.x) + s.y * 7.0)) * cr * 0.06
		var spin := churn * (_time * 5.0 + s.z * TAU)
		var toss := Vector2(0, -churn * r * 0.45 * absf(sin(_time * (7.0 + s.y * 4.0) + s.x * 6.0)))
		var p := c + rest.rotated(spin * 0.3) * (1.0 - churn * 0.2) + toss + bob
		if p.distance_to(c) > r - cr:
			p = c + (p - c).normalized() * (r - cr)
		_capsule(p, cr, CAPSULE_COLORS[i % CAPSULE_COLORS.size()], s.y * TAU * 0.3 + spin + sin(_time + s.x * 5.0) * 0.1)


## One two-tone capsule: a coloured top half, a cream bottom, a seam and a
## shine. Drawn in the machine's design space.
func _capsule(p: Vector2, radius: float, top: Color, angle: float) -> void:
	var k := _scale()
	var o := _origin(k)
	var at := o + p * k
	var rk := radius * k
	draw_set_transform(at, angle, Vector2(rk, rk))
	draw_circle(Vector2.ZERO, 1.0, CREAM)
	draw_colored_polygon(_half, top)
	draw_set_transform(at, angle, Vector2.ONE)
	draw_line(Vector2(-rk, 0), Vector2(rk, 0), top.darkened(0.35), 2.0 * k, true)
	draw_arc(Vector2.ZERO, rk, 0.0, TAU, 32, top.darkened(0.45), 2.0 * k, true)
	draw_circle(Vector2(-rk * 0.35, -rk * 0.45), rk * 0.18, Color(1, 1, 1, 0.7))
	draw_set_transform(o, 0.0, Vector2(k, k))


func _draw_crank(at: Vector2, radius: float) -> void:
	draw_circle(at + Vector2(0, 5), radius + 6.0, Color(0, 0, 0, 0.25))
	draw_circle(at, radius + 6.0, GOLD.darkened(0.35))
	draw_circle(at, radius, GOLD)
	draw_circle(at, radius * 0.32, GOLD.darkened(0.45))
	var arm := Vector2.from_angle(_crank - PI * 0.25) * radius * 0.95
	draw_line(at - arm, at + arm, CREAM, radius * 0.32, true)
	draw_circle(at + arm, radius * 0.22, CREAM)
	draw_circle(at + arm, radius * 0.1, GOLD.darkened(0.2))


func _draw_slot(rect: Rect2) -> void:
	var font := UiKit.display_font()
	draw_style_box(_slot_box, rect)
	draw_rect(Rect2(rect.position + Vector2(10, rect.size.y * 0.44), Vector2(18, rect.size.y * 0.14)), Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(rect.position.x + 30, rect.position.y + 29), "x%d" % capsule_count, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 36, 26, GOLD)
	draw_string(font, Vector2(rect.position.x, rect.position.y - 6), "INSERT", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 16, CREAM)


## The chute: a dark door the capsule rattles down into, lit by its glow.
func _draw_chute(rect: Rect2) -> void:
	draw_style_box(_chute_box, rect)
	if _chute_glow > 0.0:
		for i in 4:
			draw_circle(rect.get_center(), rect.size.x * (0.35 + i * 0.12), Color(_drop_color, 0.12 * _chute_glow))
	if _drop >= 0.0:
		var cr := rect.size.x * 0.3
		var p := Vector2(rect.get_center().x, lerpf(rect.position.y - cr, rect.end.y - cr - 6.0, _drop))
		p.x += sin(_time * 40.0) * 3.0 * (1.0 - _drop)
		_capsule(p, cr, _drop_color, sin(_time * 30.0) * 0.3 * (1.0 - _drop))
	draw_rect(Rect2(rect.position + Vector2(6, 6), Vector2(rect.size.x - 12, 6)), Color(1, 1, 1, 0.1))
