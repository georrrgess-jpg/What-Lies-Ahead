class_name CosmeticIcon
extends Control
## Flat, drawn icons for cosmetics that have no thumbnail: energy cells, kill
## effects, tracers and sights (Locker and Shop cards). Animated cells and
## rainbow tracers cycle their colours; everything else draws once.

## Kill effects and tracers drawn as one picture of their main prop or pattern.
const PROP_EFFECTS := ["balloon", "disco", "jackpot", "voxel", "ghost", "snow_globe", "black_hole", "tickets", "pinata"]
const PATTERN_TRACERS := ["ribbon", "morse", "heartbeat", "fence", "bubbles", "neon", "tickets", "chevrons", "candy"]

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
	c = WeaponCosmetics.cell_glow_color(c)
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
	if effect in PROP_EFFECTS:
		_draw_prop_effect(effect, cols, mid, r)
		return
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
	if style in PATTERN_TRACERS:
		_draw_pattern_tracer(style, c0, c1, y, x0, x1)
		return
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


## The newer kill effects: their main prop in the middle, a few bits round it.
func _draw_prop_effect(effect: String, cols: Array, mid: Vector2, r: float) -> void:
	var c0: Color = cols[0]
	var c1: Color = cols[1 % cols.size()]
	for i in 8:
		var a := TAU * i / 8.0 + 0.4
		var p := mid + Vector2(cos(a), sin(a)) * r * 1.15
		var c: Color = cols[i % cols.size()]
		match effect:
			"snow_globe": _snowflake(p, r * 0.12, c)
			"black_hole": _star(mid + Vector2(cos(a + 0.6), sin(a + 0.6) * 0.5) * r * (0.9 + 0.08 * i), r * 0.09, c)
			"voxel": draw_rect(Rect2(((mid + Vector2(cos(a), sin(a)) * r * 0.95) / 6.0).round() * 6.0, Vector2(r * 0.14, r * 0.14)), c)
			"jackpot", "ghost": pass
			_: _confetti_piece(p, r * 0.13, c, a)
	match effect:
		"balloon":
			var w := r * 0.2
			for seg in [[Vector2(-0.6, 0.1), Vector2(0.3, 0.1)], [Vector2(0.35, 0.05), Vector2(0.5, -0.45)], [Vector2(0.5, -0.5), Vector2(0.95, -0.5)],
					[Vector2(0.3, 0.2), Vector2(0.35, 0.75)], [Vector2(-0.55, 0.2), Vector2(-0.6, 0.75)], [Vector2(-0.65, 0.0), Vector2(-0.85, -0.45)]]:
				var a2: Vector2 = mid + seg[0] * r
				var b2: Vector2 = mid + seg[1] * r
				draw_line(a2, b2, c0, w * 2.0)
				draw_circle(a2, w, c0)
				draw_circle(b2, w, c0)
			draw_circle(mid + Vector2(-0.88, -0.5) * r, w * 1.2, c0)
			draw_circle(mid + Vector2(-0.3, -0.02) * r, w * 0.45, Color(1, 1, 1, 0.6))
		"disco":
			for k in 5:
				var a3 := 0.5 + k * 0.55
				var tip := mid + Vector2(cos(a3), sin(a3)) * r * 1.5
				draw_colored_polygon(PackedVector2Array([mid, tip + Vector2(sin(a3), -cos(a3)) * r * 0.2, tip - Vector2(sin(a3), -cos(a3)) * r * 0.2]), Color(cols[k % cols.size()], 0.55))
			draw_circle(mid, r * 0.6, Color(0.62, 0.65, 0.75))
			for k in 5:
				var yy := mid.y - r * 0.6 + r * 0.24 * (k + 0.5)
				var half := sqrt(maxf(0.0, r * r * 0.36 - (yy - mid.y) * (yy - mid.y)))
				draw_line(Vector2(mid.x - half, yy), Vector2(mid.x + half, yy), Color(0.4, 0.42, 0.55), 2.0)
			for k in 4:
				draw_line(Vector2(mid.x - r * 0.6 + r * 0.3 * (k + 0.5) * 0.8 + r * 0.06, mid.y - r * 0.55), Vector2(mid.x - r * 0.6 + r * 0.3 * (k + 0.5) * 0.8 + r * 0.06, mid.y + r * 0.55), Color(0.4, 0.42, 0.55), 2.0)
			draw_circle(mid + Vector2(-0.22, -0.25) * r, r * 0.13, Color.WHITE)
		"jackpot":
			var font := ThemeDB.fallback_font
			var fs := int(r * 1.2)
			var at := mid + Vector2(-r * 1.05, r * 0.42)
			draw_string_outline(font, at, "777", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(r * 0.25), c0)
			draw_string(font, at, "777", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.95, 0.15, 0.25))
			for k in 7:
				for row in [-1.0, 1.0]:
					draw_circle(mid + Vector2(-r * 1.2 + k * r * 0.4, row * r * 0.85), r * 0.08, c0 if k % 2 == 0 else Color.WHITE)
		"voxel":
			for y in 7:
				for x in 3 if y > 1 else 2:
					var cell := Rect2(mid + Vector2((x - (1.5 if y > 1 else 1.0)) * r * 0.24, (y - 3.5) * r * 0.24), Vector2(r * 0.2, r * 0.2))
					draw_rect(cell, Color(cols[(x + y) % cols.size()], 1.0 - y * 0.08))
		"ghost":
			var pts := PackedVector2Array()
			for i in 13:
				var a4 := PI + PI * i / 12.0
				pts.append(mid + Vector2(cos(a4), sin(a4)) * r * 0.62 + Vector2(0, -r * 0.1))
			for i in 7:
				var x := r * 0.62 - r * 1.24 * i / 6.0
				pts.append(mid + Vector2(x, r * (0.7 if i % 2 == 0 else 0.5)))
			draw_colored_polygon(pts, c0)
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color(UiKit.INK, 0.6), 2.0, true)
			for side in [-1.0, 1.0]:
				draw_circle(mid + Vector2(side * r * 0.22, -r * 0.15), r * 0.1, UiKit.INK)
				draw_circle(mid + Vector2(side * r * 0.38, r * 0.05), r * 0.08, Color(1.0, 0.55, 0.7, 0.8))
		"snow_globe":
			draw_rect(Rect2(mid + Vector2(-r * 0.6, r * 0.55), Vector2(r * 1.2, r * 0.35)), Color(1.0, 0.75, 0.3))
			draw_rect(Rect2(mid + Vector2(-r * 0.62, r * 0.68), Vector2(r * 1.24, r * 0.08)), Color(0.9, 0.2, 0.32))
			draw_circle(mid, r * 0.7, Color(c1, 0.25))
			draw_colored_polygon(PackedVector2Array([mid + Vector2(0, -r * 0.35), mid + Vector2(r * 0.3, r * 0.45), mid + Vector2(-r * 0.3, r * 0.45)]), Color(0.2, 0.7, 0.42))
			draw_arc(mid, r * 0.7, 0.0, TAU, 40, Color(1, 1, 1, 0.85), 3.0, true)
			draw_arc(mid, r * 0.55, -2.5, -1.7, 12, Color(1, 1, 1, 0.9), 3.0, true)
		"black_hole":
			draw_set_transform(mid, -0.3, Vector2(1.0, 0.42))
			draw_arc(Vector2.ZERO, r * 0.95, 0.0, TAU, 48, c0, 6.0, true)
			draw_arc(Vector2.ZERO, r * 0.75, 0.0, TAU, 48, c1, 4.0, true)
			draw_set_transform(Vector2.ZERO)
			draw_circle(mid, r * 0.42, Color(0.03, 0.0, 0.06))
			draw_arc(mid, r * 0.44, 0.0, TAU, 32, Color(c0, 0.8), 2.0, true)
		"tickets":
			for k in 3:
				_ticket(mid + Vector2((k - 1) * r * 0.6, (k - 1) * -r * 0.25), r * 0.85, -0.4 + k * 0.4, cols[k % cols.size()])
		"pinata":
			for k in 3:
				var a5 := -0.5 + k * 1.0
				var p2 := mid + Vector2(cos(a5 * 2.0), sin(a5 * 2.0)) * r * 0.35
				var c: Color = cols[k % cols.size()]
				draw_colored_polygon(PackedVector2Array([p2 + Vector2(-r * 0.2, 0), p2 + Vector2(-r * 0.45, -r * 0.15), p2 + Vector2(-r * 0.45, r * 0.15)]), c.lightened(0.2))
				draw_colored_polygon(PackedVector2Array([p2 + Vector2(r * 0.2, 0), p2 + Vector2(r * 0.45, -r * 0.15), p2 + Vector2(r * 0.45, r * 0.15)]), c.lightened(0.2))
				draw_circle(p2, r * 0.24, c)


func _ticket(p: Vector2, w: float, angle: float, c: Color) -> void:
	draw_set_transform(p, angle)
	draw_rect(Rect2(-w * 0.5, -w * 0.25, w, w * 0.5), c)
	draw_rect(Rect2(-w * 0.36, -w * 0.15, w * 0.72, w * 0.3), c.darkened(0.25), false, 2.0)
	_star(Vector2.ZERO, w * 0.12, Color(1, 1, 1, 0.9))
	draw_set_transform(Vector2.ZERO)


## The pattern tracers and the bubble stream.
func _draw_pattern_tracer(style: String, c0: Color, c1: Color, y: float, x0: float, x1: float) -> void:
	var h := size.y
	match style:
		"ribbon":
			for i in 24:
				var t0 := i / 24.0
				var t1 := (i + 1) / 24.0
				var w := absf(cos(t0 * TAU * 1.5)) * h * 0.14 + 2.0
				draw_line(Vector2(lerpf(x0, x1, t0), y), Vector2(lerpf(x0, x1, t1), y), c0 if fmod(t0 * 3.0 + 0.25, 1.0) < 0.5 else c1, w)
		"morse":
			var x := x0
			for run in [1, 3, 3, 1, 0, 3, 3, 3, 0, 1, 3]:
				if run > 0:
					var len: float = run * h * 0.05
					draw_line(Vector2(x + h * 0.025, y), Vector2(x + len - h * 0.025, y), c0, h * 0.05)
					draw_circle(Vector2(x + h * 0.025, y), h * 0.025, c0)
					draw_circle(Vector2(x + len - h * 0.025, y), h * 0.025, c0)
					x += len + h * 0.04
				else:
					x += h * 0.08
		"heartbeat":
			var pts := PackedVector2Array()
			for k in 2:
				var bx := lerpf(x0, x1, k * 0.5)
				var seg := (x1 - x0) * 0.5
				for v in [[0.0, 0.0], [0.3, 0.0], [0.36, -0.05], [0.42, 0.0], [0.5, 0.06], [0.56, -0.3], [0.62, 0.15], [0.68, 0.0], [0.8, -0.06], [0.9, 0.0]]:
					pts.append(Vector2(bx + seg * v[0], y + h * v[1]))
			pts.append(Vector2(x1, y))
			draw_polyline(pts, Color(c0, 0.4), 9.0, true)
			draw_polyline(pts, c0.lerp(Color.WHITE, 0.3), 4.0, true)
		"fence":
			for side in [-1.0, 1.0]:
				draw_line(Vector2(x0, y + side * h * 0.12), Vector2(x1, y + side * h * 0.12), c0, 4.0)
			for i in 9:
				var xx := lerpf(x0, x1, (i + 0.5) / 9.0)
				draw_line(Vector2(xx, y - h * 0.12), Vector2(xx, y + h * 0.12), c1, 3.0)
		"bubbles":
			draw_line(Vector2(x0, y), Vector2(x1, y), c0, 3.0)
			for i in 7:
				var p := Vector2(lerpf(x0, x1, (i + 0.5) / 7.0), y - h * (0.08 + 0.08 * float(i % 3)))
				draw_arc(p, h * (0.05 + 0.02 * float(i % 2)), 0.0, TAU, 20, c1 if i % 2 else c0, 2.5, true)
		"neon":
			draw_line(Vector2(x0, y), Vector2(x1, y), Color(c0, 0.25), h * 0.26)
			draw_line(Vector2(x0, y), Vector2(x1, y), c0, h * 0.13)
			draw_line(Vector2(x0, y), Vector2(x1, y), c0.lerp(Color.WHITE, 0.8), h * 0.04)
		"tickets":
			for i in 4:
				var w := (x1 - x0) / 4.0
				var cx := x0 + w * (i + 0.5)
				draw_rect(Rect2(cx - w * 0.47, y - h * 0.11, w * 0.94, h * 0.22), c0)
				draw_rect(Rect2(cx - w * 0.36, y - h * 0.07, w * 0.72, h * 0.14), c1, false, 2.0)
				_star(Vector2(cx, y), h * 0.045, c1)
		"chevrons":
			for i in 5:
				var cx := lerpf(x0, x1, (i + 0.5) / 5.0)
				draw_polyline(PackedVector2Array([Vector2(cx - h * 0.08, y - h * 0.14), Vector2(cx + h * 0.04, y), Vector2(cx - h * 0.08, y + h * 0.14)]), c0, 6.0, true)
		"candy":
			var r := h * 0.08
			draw_line(Vector2(x0, y), Vector2(x1, y), c1, r * 2.0)
			var x2 := x0
			while x2 < x1 - r:
				draw_colored_polygon(PackedVector2Array([Vector2(x2, y + r), Vector2(x2 + r, y + r), Vector2(minf(x2 + r * 2.0, x1), y - r), Vector2(minf(x2 + r, x1), y - r)]), c0)
				x2 += r * 2.6
