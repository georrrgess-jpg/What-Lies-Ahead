class_name FusionChamber
extends Control
## The Prize Fusion machine, drawn: five glowing pods around a glass core,
## holographic rings that turn around it, beams from the pods to the core and
## streams of light that carry dissolving prints into it. The Trade-Up tab
## shows it idle (pods hold the picked prints; click a pod to take its print
## out); FusionReveal spins it up, dissolves the prints and flashes the core.
## Everything scales with the control; the stream particles are a fixed pool.

## A pod was clicked (the Trade-Up tab takes that print out).
signal pod_pressed(index: int)

const PODS := 5
const STREAM := 120
const CYAN := Color("35f0ff")
const VIOLET := Color("9f8bff")
const DEEP := Color("0b1030")

## What each pod holds (null = empty) and its rim colour.
var pod_textures: Array[Texture2D] = [null, null, null, null, null]
var pod_colors: Array[Color] = [CYAN, CYAN, CYAN, CYAN, CYAN]
## 0-1 per pod: the print breaking up into light.
var dissolve := PackedFloat32Array([0, 0, 0, 0, 0])
## 0-1: beams on, rings faster, the core charging.
var charge := 0.0
## 0-1: the light streams flowing into the core.
var stream := 0.0
## 0-1: the core's brightness; and its colour (the next rarity).
var core := 0.0
var core_color := VIOLET
## Text in the core while idle ("?", or the rarity coming out).
var core_text := "?"
var _time := 0.0
var _spin := 0.0
var _s_t := PackedFloat32Array()
var _s_pod := PackedInt32Array()
var _s_off := PackedFloat32Array()
var _ring := PackedVector2Array()
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	custom_minimum_size = Vector2(520, 420)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_s_t.resize(STREAM)
	_s_pod.resize(STREAM)
	_s_off.resize(STREAM)
	for i in STREAM:
		_s_t[i] = _rng.randf()
		_s_pod[i] = i % PODS
		_s_off[i] = _rng.randf_range(-1.0, 1.0)
	_ring.resize(49)


func _process(delta: float) -> void:
	_time += delta
	_spin += delta * (0.35 + charge * 5.5)
	if stream > 0.0:
		for i in STREAM:
			_s_t[i] += delta * (0.9 + 0.6 * absf(_s_off[i]))
			if _s_t[i] > 1.0:
				_s_t[i] -= 1.0
	if is_visible_in_tree():
		queue_redraw()


## Empties the pods and resets every effect.
func reset() -> void:
	for i in PODS:
		pod_textures[i] = null
		pod_colors[i] = CYAN
		dissolve[i] = 0.0
	charge = 0.0
	stream = 0.0
	core = 0.0


## (Value first: tween_method passes it before the bound pod index.)
func set_dissolve(v: float, i: int) -> void:
	dissolve[i] = v


## The core's centre and radius, in this control's space.
func core_point() -> Vector2:
	return size * Vector2(0.5, 0.52)


func _unit() -> float:
	return minf(size.x / 1.25, size.y)


func core_radius() -> float:
	return _unit() * 0.16


## The rectangle of pod `i`: a pentagon of pods around the core.
func pod_rect(i: int) -> Rect2:
	var u := _unit()
	var pod := Vector2(u * 0.21, u * 0.21)
	var a := -PI * 0.5 + TAU * i / PODS
	var at := core_point() + Vector2(cos(a) * u * 0.5, sin(a) * u * 0.38)
	return Rect2(at - pod * 0.5, pod)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		for i in PODS:
			if pod_rect(i).has_point(click.position):
				pod_pressed.emit(i)
				accept_event()
				return


func _draw() -> void:
	var c := core_point()
	var r := core_radius()
	var u := _unit()
	# The floor: a glowing disc and a faint grid of rings and spokes.
	draw_set_transform(c + Vector2(0, u * 0.36), 0.0, Vector2(1.0, 0.28))
	for k in 5:
		draw_circle(Vector2.ZERO, u * (0.62 - k * 0.1), Color(CYAN, 0.035 + 0.03 * charge))
	draw_set_transform(Vector2.ZERO)
	for k in 3:
		draw_arc(c, u * (0.32 + k * 0.14), 0.0, TAU, 64, Color(CYAN, 0.06 + 0.04 * charge), 1.5, true)
	_draw_beams(c)
	_draw_rings(c, r)
	_draw_core(c, r)
	if stream > 0.0:
		_draw_stream(c)
	for i in PODS:
		_draw_pod(i)


func _draw_beams(c: Vector2) -> void:
	if charge <= 0.0:
		return
	for i in PODS:
		var from := pod_rect(i).get_center()
		var pulse := 0.6 + 0.4 * sin(_time * 14.0 + i * 1.3)
		draw_line(from, c, Color(pod_colors[i].lerp(CYAN, 0.5), 0.25 * charge * pulse), 14.0 * charge, true)
		draw_line(from, c, Color(1, 1, 1, 0.55 * charge * pulse), 3.0, true)


## Three tilted holographic rings of dashes turning round the core.
func _draw_rings(c: Vector2, r: float) -> void:
	for k in 3:
		var radius := r * (1.35 + k * 0.32)
		var tilt := 0.32 + k * 0.12
		var turn := _spin * (1.0 if k % 2 == 0 else -1.3) + k
		var col := CYAN.lerp(VIOLET, k * 0.4)
		for j in _ring.size():
			var a := TAU * j / (_ring.size() - 1)
			_ring[j] = c + Vector2(cos(a) * radius, sin(a) * radius * tilt).rotated(0.25 * (k - 1))
		draw_polyline(_ring, Color(col, 0.18 + 0.2 * charge), 2.0, true)
		for d in 6:
			var a := turn + TAU * d / 6.0
			var p := c + Vector2(cos(a) * radius, sin(a) * radius * tilt).rotated(0.25 * (k - 1))
			draw_circle(p, 4.0 + 3.0 * charge, Color(col.lerp(Color.WHITE, 0.4), 0.55 + 0.4 * charge))


func _draw_core(c: Vector2, r: float) -> void:
	var col := core_color.lerp(CYAN, 0.35)
	for k in 6:
		draw_circle(c, r * (1.0 + k * 0.22 + core * 0.6), Color(col, (0.05 + 0.1 * core + 0.04 * charge) * (1.0 - k / 6.0)))
	draw_circle(c, r, DEEP)
	draw_circle(c, r * (0.55 + 0.4 * core), Color(col.lerp(Color.WHITE, core), 0.25 + 0.75 * core))
	draw_arc(c, r, 0.0, TAU, 64, Color(col, 0.9), 4.0, true)
	draw_arc(c, r * 0.82, _spin * 2.0, _spin * 2.0 + PI * 0.6, 24, Color(1, 1, 1, 0.35), 3.0, true)
	draw_arc(c - Vector2(r * 0.25, r * 0.3), r * 0.5, PI * 1.1, PI * 1.5, 16, Color(1, 1, 1, 0.35), 5.0, true)
	if core < 0.5 and core_text != "":
		var font := UiKit.display_font()
		var fs := int(r * 0.9)
		draw_string(font, c + Vector2(-r, fs * 0.36), core_text, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color(core_color.lerp(Color.WHITE, 0.3), 1.0 - core * 2.0))


## The streams of light: particles curving from each dissolving pod into the core.
func _draw_stream(c: Vector2) -> void:
	for i in STREAM:
		var pod := _s_pod[i]
		if dissolve[pod] <= 0.02:
			continue
		var from := pod_rect(pod).get_center()
		var t := _s_t[i]
		var side := (c - from).orthogonal().normalized() * _s_off[i] * _unit() * 0.12
		var mid := (from + c) * 0.5 + side
		var p := from.lerp(mid, t).lerp(mid.lerp(c, t), t)
		var a := stream * sin(t * PI) * minf(1.0, dissolve[pod] * 2.0)
		draw_circle(p, 3.0 + 3.0 * (1.0 - t), Color(pod_colors[pod].lerp(Color.WHITE, 0.5), a))


func _draw_pod(i: int) -> void:
	var rect := pod_rect(i)
	var col := pod_colors[i]
	var lit := 0.5 + 0.5 * sin(_time * 3.0 + i)
	draw_rect(rect.grow(6.0), Color(col, 0.08 + 0.1 * charge + 0.04 * lit))
	draw_rect(rect, Color(DEEP, 0.92))
	var tex := pod_textures[i]
	var d := dissolve[i]
	if tex:
		_draw_print(tex, rect.grow(-6.0), d, col)
	else:
		var font := UiKit.display_font()
		var fs := int(rect.size.x * 0.32)
		draw_string(font, rect.position + Vector2(0, rect.size.y * 0.5 + fs * 0.35), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, fs, Color(CYAN, 0.35))
	draw_rect(rect, Color(col, 0.85 if tex else 0.45), false, 3.0)
	var bracket := rect.size.x * 0.18
	for corner in 4:
		var at := Vector2(rect.position.x if corner % 2 == 0 else rect.end.x, rect.position.y if corner < 2 else rect.end.y)
		var sx := 1.0 if corner % 2 == 0 else -1.0
		var sy := 1.0 if corner < 2 else -1.0
		draw_line(at, at + Vector2(bracket * sx, 0), Color(CYAN.lerp(Color.WHITE, lit * 0.4), 0.9), 4.0)
		draw_line(at, at + Vector2(0, bracket * sy), Color(CYAN.lerp(Color.WHITE, lit * 0.4), 0.9), 4.0)


## The print in its pod, breaking up into horizontal slices of light as `d` rises.
func _draw_print(tex: Texture2D, rect: Rect2, d: float, col: Color) -> void:
	var slices := 10
	var ts := tex.get_size()
	for s in slices:
		var k := float(s) / slices
		var local := clampf(d * 1.6 - (1.0 - k) * 0.6, 0.0, 1.0)
		if local >= 1.0:
			continue
		var jitter := sin(_time * 40.0 + s * 7.0) * rect.size.x * 0.12 * local
		var dest := Rect2(rect.position.x + jitter, rect.position.y + rect.size.y * k, rect.size.x, rect.size.y / slices + 0.5)
		var src := Rect2(0.0, ts.y * k, ts.x, ts.y / slices)
		draw_texture_rect_region(tex, dest, src, Color(1, 1, 1, 1.0 - local).lerp(Color(col.lerp(Color.WHITE, 0.6), 1.0 - local), local))
