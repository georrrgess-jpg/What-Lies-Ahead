class_name CapsuleMachine
extends Control
## The Prize Capsule machine (approved concept media/concepts/c1_capsules.png),
## drawn and animated: a glass globe of two-tone capsules that jostle, a
## marquee sign with chasing bulbs, a gold crank, a coin slot and the chute a
## capsule rattles down. turn() plays the crank-and-drop and calls back when
## the capsule sits in the chute (the reveal takes it from there).
##
##   machine.turn(rarity_color, func(): reveal.start(...))

signal turned

const CAPSULES := 15
const BODY := Color("e8417e")
const BODY_DARK := Color("a8205a")
const GOLD := Color("ffc24a")
const GLASS := Color(0.55, 0.78, 1.0, 0.13)
const CREAM := Color("fff3dc")
const CAPSULE_COLORS := [Color("8fe3ff"), Color("ff6fb5"), Color("ffd35c"), Color("b98cff"), Color("7dffa8"), Color("ff9a5c")]

## The sign: "SERIES 1" over the series name.
var series_text := "SERIES 1"
var series_name := ""
## How many capsules the player has (drawn as a counter on the body).
var capsule_count := 0
var _time := 0.0
var _crank := 0.0
var _churn := 0.0
var _drop := -1.0
var _drop_color := CREAM
var _seeds: Array[Vector3] = []
var _clicks := 0


func _init() -> void:
	custom_minimum_size = Vector2(440, 420)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for i in CAPSULES:
		_seeds.append(Vector3(rng.randf(), rng.randf(), rng.randf()))


func _process(delta: float) -> void:
	_time += delta
	if is_visible_in_tree():
		queue_redraw()


## Turns the crank (ratchet clicks), churns the globe and drops a capsule of
## `color` down the chute; emits `turned` when it lands.
func turn(color: Color) -> void:
	_drop_color = color
	_clicks = 0
	var tw := create_tween()
	tw.tween_method(_set_crank, 0.0, TAU, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(self, "_churn", 1.0, 0.3)
	tw.tween_callback(func(): Sfx.play(&"prz_rattle", -4.0))
	tw.tween_property(self, "_drop", 1.0, 0.45).from(0.0).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "_churn", 0.0, 0.6)
	tw.tween_callback(func(): _crank = 0.0)
	tw.tween_callback(turned.emit)


## Hides the dropped capsule (the reveal has taken it).
func take_capsule() -> void:
	_drop = -1.0


## Where the capsule in the chute is, in this control's space (for the reveal to fly from).
func chute_point() -> Vector2:
	var g := _geometry()
	return g["chute"].get_center()


func _set_crank(a: float) -> void:
	_crank = a
	var click := int(a / (TAU / 6.0))
	if click > _clicks:
		_clicks = click
		Sfx.play(&"prz_crank", -8.0, 0.95 + 0.03 * click)


func _geometry() -> Dictionary:
	var w := size.x
	var h := size.y
	var r := minf(w * 0.4, h * 0.27)
	var globe_c := Vector2(w * 0.5, 92.0 + r)
	var body := Rect2(w * 0.5 - r * 1.15, globe_c.y + r * 0.82, r * 2.3, h - (globe_c.y + r * 0.82) - 8.0)
	var chute := Rect2(body.position.x + body.size.x * 0.56, body.position.y + body.size.y * 0.42, body.size.x * 0.32, body.size.y * 0.4)
	return {"r": r, "globe": globe_c, "body": body, "chute": chute}


func _draw() -> void:
	var g := _geometry()
	var r: float = g["r"]
	var c: Vector2 = g["globe"]
	var body: Rect2 = g["body"]
	_draw_sign(Vector2(c.x, c.y - r - 34.0), r)
	# The globe: a gold rim, the glass, the capsules inside and a highlight.
	draw_circle(c, r + 10.0, GOLD.darkened(0.25))
	draw_circle(c, r + 4.0, GOLD)
	draw_circle(c, r, Color("1b1446"))
	_draw_capsules(c, r)
	draw_circle(c, r, GLASS)
	draw_arc(c - Vector2(r * 0.2, r * 0.22), r * 0.68, PI * 1.05, PI * 1.45, 24, Color(1, 1, 1, 0.45), 10.0, true)
	# The body: a rounded pink box with a darker base and a shine.
	var base := StyleBoxFlat.new()
	base.bg_color = BODY
	base.set_corner_radius_all(26)
	base.border_color = BODY_DARK
	base.set_border_width_all(6)
	base.shadow_color = Color(0, 0, 0, 0.35)
	base.shadow_size = 14
	draw_style_box(base, body)
	draw_rect(Rect2(body.position + Vector2(20, 12), Vector2(body.size.x - 40, 8)), Color(1, 1, 1, 0.18))
	_draw_crank(body.position + Vector2(body.size.x * 0.24, body.size.y * 0.36), body.size.x * 0.15)
	_draw_slot(body.position + Vector2(body.size.x * 0.56, body.size.y * 0.12), Vector2(body.size.x * 0.32, body.size.y * 0.24))
	_draw_chute(g["chute"])
	var font := UiKit.display_font()
	draw_string(font, body.position + Vector2(body.size.x * 0.24 - 60.0, body.size.y * 0.86), "TURN!", HORIZONTAL_ALIGNMENT_CENTER, 120.0, 30, CREAM)
	draw_string(font, body.position + Vector2(body.size.x * 0.56, body.size.y * 0.1), "INSERT", HORIZONTAL_ALIGNMENT_CENTER, body.size.x * 0.32, 18, CREAM)
	draw_string(font, body.position + Vector2(body.size.x * 0.56, body.size.y * 0.29), "x%d" % capsule_count, HORIZONTAL_ALIGNMENT_CENTER, body.size.x * 0.32, 26, GOLD)


func _draw_sign(at: Vector2, r: float) -> void:
	var font := UiKit.display_font()
	var rect := Rect2(at.x - r * 1.15, at.y - 46.0, r * 2.3, 74.0)
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color("8f1d3f")
	plate.set_corner_radius_all(14)
	plate.border_color = GOLD
	plate.set_border_width_all(4)
	draw_style_box(plate, rect)
	# Chasing bulbs around the sign.
	var bulbs := 14
	for i in bulbs:
		var t := float(i) / bulbs
		var p := rect.position + Vector2(rect.size.x * t + rect.size.x / bulbs * 0.5, -1.0)
		var q := rect.position + Vector2(rect.size.x * t + rect.size.x / bulbs * 0.5, rect.size.y + 1.0)
		var lit := int(_time * 6.0 + i) % 3 == 0
		draw_circle(p, 4.0, CREAM if lit else GOLD.darkened(0.3))
		draw_circle(q, 4.0, CREAM if not lit else GOLD.darkened(0.3))
	draw_string(font, Vector2(rect.position.x, rect.position.y + 38.0), series_text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 32, CREAM)
	draw_string(font, Vector2(rect.position.x, rect.position.y + 62.0), series_name, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 20, GOLD)


## The capsules heaped in the globe: they settle at the bottom and bob; the
## crank churns them round.
func _draw_capsules(c: Vector2, r: float) -> void:
	var cr := r * 0.2
	for i in CAPSULES:
		var s := _seeds[i]
		var row := i / 5
		var col := i % 5
		var rest := Vector2((col - 2.0) * cr * 1.75 + (row % 2) * cr * 0.6, r * 0.55 - row * cr * 1.55)
		rest.x += (s.x - 0.5) * cr * 0.5
		var bob := Vector2(sin(_time * (1.2 + s.y) + s.z * 9.0), cos(_time * (1.0 + s.x) + s.y * 7.0)) * cr * 0.06
		var spin := _churn * (_time * 5.0 + s.z * TAU)
		var churned := rest.rotated(spin * 0.25) * (1.0 - _churn * 0.25) + Vector2(0, -_churn * r * 0.25 * sin(_time * 9.0 + s.x * 6.0))
		var p := c + churned + bob
		if p.distance_to(c) > r - cr:
			p = c + (p - c).normalized() * (r - cr)
		_capsule(p, cr, CAPSULE_COLORS[i % CAPSULE_COLORS.size()], s.y * TAU * 0.3 + spin + sin(_time + s.x * 5.0) * 0.1)


## The top half of a unit circle, built once (drawn scaled per capsule, so
## the per-frame redraw allocates nothing).
static var _half: PackedVector2Array


static func _half_disc() -> PackedVector2Array:
	if _half.is_empty():
		for k in 17:
			var a := PI + PI * k / 16.0
			_half.append(Vector2(cos(a), sin(a)))
	return _half


## One two-tone capsule: a coloured top half, a cream bottom, a seam and a shine.
func _capsule(p: Vector2, radius: float, top: Color, angle: float) -> void:
	draw_set_transform(p, angle, Vector2(radius, radius))
	draw_circle(Vector2.ZERO, 1.0, CREAM)
	draw_colored_polygon(_half_disc(), top)
	draw_set_transform(p, angle, Vector2.ONE)
	draw_line(Vector2(-radius, 0), Vector2(radius, 0), top.darkened(0.35), 2.0, true)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, top.darkened(0.45), 2.0, true)
	draw_circle(Vector2(-radius * 0.35, -radius * 0.45), radius * 0.18, Color(1, 1, 1, 0.7))
	draw_set_transform(Vector2.ZERO)


func _draw_crank(at: Vector2, radius: float) -> void:
	draw_circle(at, radius + 6.0, GOLD.darkened(0.35))
	draw_circle(at, radius, GOLD)
	draw_circle(at, radius * 0.32, GOLD.darkened(0.45))
	var arm := Vector2.from_angle(_crank - PI * 0.25) * radius * 0.95
	draw_line(at - arm, at + arm, CREAM, radius * 0.32, true)
	draw_circle(at + arm, radius * 0.2, CREAM)


func _draw_slot(at: Vector2, slot_size: Vector2) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("1b1446")
	box.set_corner_radius_all(8)
	box.border_color = GOLD
	box.set_border_width_all(3)
	draw_style_box(box, Rect2(at, slot_size))
	draw_rect(Rect2(at + Vector2(slot_size.x * 0.2, slot_size.y * 0.42), Vector2(slot_size.x * 0.6, slot_size.y * 0.16)), Color(0, 0, 0, 0.8))


## The chute: a dark door the capsule rattles down into.
func _draw_chute(rect: Rect2) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("120c2e")
	box.set_corner_radius_all(12)
	box.border_color = GOLD
	box.set_border_width_all(4)
	draw_style_box(box, rect)
	if _drop >= 0.0:
		var cr := rect.size.x * 0.3
		var p := Vector2(rect.get_center().x, lerpf(rect.position.y - cr, rect.end.y - cr - 6.0, _drop))
		p.x += sin(_time * 40.0) * 3.0 * (1.0 - _drop)
		draw_circle(p, cr * 1.6, Color(_drop_color, 0.25 * _drop))
		_capsule(p, cr, _drop_color, sin(_time * 30.0) * 0.3 * (1.0 - _drop))
	draw_rect(Rect2(rect.position + Vector2(6, 6), Vector2(rect.size.x - 12, 6)), Color(1, 1, 1, 0.1))
