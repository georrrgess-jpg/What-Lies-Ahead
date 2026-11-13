class_name CosmeticIcon
extends Control
## Flat, drawn icons for cosmetics that have no thumbnail: energy cells, kill
## effects, tracers and sights (Locker and Shop cards). Animated cells and
## rainbow tracers cycle their colours; everything else draws once.

var item: CosmeticItem
var _time := 0.0


func _init(it: CosmeticItem = null) -> void:
	item = it
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(item != null and (item.params.has("animate") or String(item.params.get("style", "")) == "rainbow"))


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if item == null:
		return
	match item.slot:
		&"weapon_cell": _draw_cell()
		&"kill_effect": _draw_kill_effect()
		&"tracer": _draw_tracer()
		&"weapon_sight": _draw_sight()


func _draw_cell() -> void:
	var c := item.color(0, Color(0.3, 0.95, 1.0))
	match String(item.params.get("animate", "")):
		"rainbow": c = Color.from_hsv(fmod(_time * 0.18, 1.0), 0.75, 1.0)
		"pulse": c = item.color(0).lerp(item.color(1, Color.WHITE), 0.5 + 0.5 * sin(_time * 3.2))
	var mid := size * 0.5
	for i in 6:
		draw_circle(mid, size.y * (0.42 - i * 0.04), Color(c, 0.06 + i * 0.02))
	var w := size.x * 0.24
	var h := size.y * 0.62
	var body := Rect2(mid - Vector2(w, h) * 0.5, Vector2(w, h))
	var sb := StyleBoxFlat.new()
	sb.bg_color = c.lerp(Color.WHITE, 0.25)
	sb.set_corner_radius_all(int(w * 0.5))
	sb.border_color = Color(UiKit.INK, 0.9)
	sb.set_border_width_all(4)
	draw_style_box(sb, body)
	draw_rect(Rect2(body.position + Vector2(w * 0.28, h * 0.14), Vector2(w * 0.14, h * 0.6)), Color(1, 1, 1, 0.75))
	for k in 2:
		var y := body.position.y + h * (0.33 + k * 0.33)
		draw_line(Vector2(body.position.x + 3, y), Vector2(body.end.x - 3, y), Color(UiKit.INK, 0.8), 5.0)


func _draw_kill_effect() -> void:
	var effect := KillEffects.effect_of(item)
	var cols := KillEffects.colors_for(item, effect)
	if effect == "confetti":
		cols = [Color(1.0, 0.85, 0.25), Color(1.0, 0.45, 0.8), Color(0.3, 0.95, 1.0)]
	var mid := size * 0.5
	var r := minf(size.x, size.y) * 0.32
	draw_circle(mid, r * 0.35, Color(cols[0], 0.35))
	draw_circle(mid, r * 0.18, Color(1, 1, 1, 0.8))
	if effect == "neon_ring":
		for k in 2:
			draw_arc(mid, r * (0.65 + k * 0.4), 0.0, TAU, 40, cols[k % cols.size()], 5.0, true)
	for i in 10:
		var a := TAU * i / 10.0 + 0.3
		var d := r * (0.85 + 0.35 * float(i % 2))
		var p := mid + Vector2(cos(a), sin(a)) * d
		var c: Color = cols[i % cols.size()]
		var s := r * 0.2
		match effect:
			"pixel": draw_rect(Rect2((p / 8.0).round() * 8.0 - Vector2(s, s) * 0.5, Vector2(s, s)), c)
			"bubbles": draw_arc(p, s * 0.8, 0.0, TAU, 20, c, 3.0, true)
			"snow": _snowflake(p, s * 0.9, c)
			"starburst", "firework": _star(p, s * (1.0 if effect == "starburst" else 0.6), c)
			"coins":
				draw_circle(p, s * 0.8, c.darkened(0.25))
				draw_circle(p, s * 0.6, c)
			"hearts": _heart(p, s * 0.9, c)
			"neon_ring": draw_line(p, p + Vector2(cos(a), sin(a)) * s * 1.6, c, 4.0)
			_: _confetti_piece(p, s, c, a)


func _draw_tracer() -> void:
	var style := String(item.params.get("style", "standard"))
	var c0 := item.color(0, Color(0.3, 0.95, 1.0))
	var c1 := item.color(1, c0.lerp(Color.WHITE, 0.5))
	var y := size.y * 0.5
	var x0 := size.x * 0.1
	var x1 := size.x * 0.9
	var pts := PackedVector2Array()
	match style:
		"helix":
			for strand in 2:
				pts.clear()
				for i in 41:
					var t := i / 40.0
					pts.append(Vector2(lerpf(x0, x1, t), y + sin(t * TAU * 2.0 + strand * PI) * size.y * 0.16))
				draw_polyline(pts, c0 if strand == 0 else c1, 6.0, true)
		"lightning":
			pts.append(Vector2(x0, y))
			for i in range(1, 8):
				pts.append(Vector2(lerpf(x0, x1, i / 8.0), y + (size.y * 0.14 if i % 2 else -size.y * 0.14)))
			pts.append(Vector2(x1, y))
			draw_polyline(pts, Color(c0, 0.45), 14.0, true)
			draw_polyline(pts, c1, 5.0, true)
		"rainbow":
			for i in 12:
				var t := i / 12.0
				draw_line(Vector2(lerpf(x0, x1, t), y), Vector2(lerpf(x0, x1, t + 1.0 / 12.0), y),
					Color.from_hsv(fmod(t * 0.9 + _time * 0.2, 1.0), 0.8, 1.0), 6.0 + t * 12.0)
		"comet":
			for i in 10:
				var t := i / 10.0
				draw_circle(Vector2(lerpf(x0, x1 - size.x * 0.12, t), y), 2.0 + t * 7.0, Color(c0, t))
			draw_circle(Vector2(x1 - size.x * 0.1, y), size.y * 0.13, c1)
			_star(Vector2(x1 - size.x * 0.1, y), size.y * 0.2, Color(c0, 0.9))
		_:
			var c := c0 if style != "standard" else Color(0.3, 0.95, 1.0)
			draw_line(Vector2(x0, y), Vector2(x1, y), Color(c, 0.35), 18.0)
			draw_line(Vector2(x0, y), Vector2(x1, y), c.lerp(Color.WHITE, 0.4), 6.0)
			if style == "sparkle":
				for i in 7:
					var p := Vector2(lerpf(x0, x1, (i + 0.5) / 7.0), y + (size.y * 0.13 if i % 2 else -size.y * 0.1))
					if item.params.get("flakes", false):
						_snowflake(p, 9.0, c1)
					else:
						_star(p, 9.0, c1 if i % 2 else Color.WHITE)


## An optic seen from behind: a lens in a housing with the reticle lit.
func _draw_sight() -> void:
	var c := item.color(0, UiKit.CYAN)
	var mid := size * 0.5
	var r := minf(size.x, size.y) * 0.34
	var housing := StyleBoxFlat.new()
	housing.bg_color = Color("2a2440")
	housing.border_color = Color("4a3b86")
	housing.set_border_width_all(4)
	housing.set_corner_radius_all(int(r * 0.45))
	draw_style_box(housing, Rect2(mid - Vector2(r * 1.25, r * 1.1), Vector2(r * 2.5, r * 2.2)))
	draw_rect(Rect2(mid.x - r * 0.9, mid.y + r * 1.1, r * 1.8, r * 0.35), Color("1b1730"))
	draw_circle(mid, r * 0.92, Color(c, 0.14))
	draw_arc(mid, r * 0.92, 0.0, TAU, 40, Color(c, 0.5), 3.0, true)
	draw_arc(mid, r * 0.42, 0.0, TAU, 28, c, 3.0, true)
	draw_circle(mid, r * 0.11, c.lerp(Color.WHITE, 0.5))
	for k in 4:
		var d := Vector2.RIGHT.rotated(TAU * k / 4.0)
		draw_line(mid + d * r * 0.55, mid + d * r * 0.82, c, 3.0, true)


func _star(p: Vector2, r: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + PI * i / 5.0
		pts.append(p + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, c)


func _heart(p: Vector2, r: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var t := TAU * i / 20.0
		pts.append(p + Vector2(16.0 * pow(sin(t), 3.0), -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))) * r / 16.0)
	draw_colored_polygon(pts, c)


func _snowflake(p: Vector2, r: float, c: Color) -> void:
	for k in 3:
		var a := PI * k / 3.0
		var d := Vector2(cos(a), sin(a)) * r
		draw_line(p - d, p + d, c, 3.0)


func _confetti_piece(p: Vector2, s: float, c: Color, a: float) -> void:
	var d := Vector2(cos(a), sin(a))
	var n := Vector2(-d.y, d.x)
	draw_colored_polygon(PackedVector2Array([p - d * s - n * s * 0.4, p + d * s - n * s * 0.4, p + d * s + n * s * 0.4, p - d * s + n * s * 0.4]), c)
