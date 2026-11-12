class_name MenuAtmosphere
extends Control
## Full-screen overlay that gives the menu depth and life: a soft vignette,
## a tinted gradient from the left (where the menu sits), drifting glowing
## motes, and faint animated scanlines. Accent colour follows the world.

const MOTES := 46

var accent := UiKit.PINK:
	set(v):
		accent = v
		queue_redraw()
var _motes: Array = []
var _time := 0.0
var _vignette: TextureRect
var _left: TextureRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_left = TextureRect.new()
	_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_left.stretch_mode = TextureRect.STRETCH_SCALE
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([Color(UiKit.INK, 0.86), Color(UiKit.INK, 0.35), Color(UiKit.INK, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 256
	gt.height = 4
	_left.texture = gt
	add_child(_left)
	_vignette = TextureRect.new()
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	var v := Gradient.new()
	v.offsets = PackedFloat32Array([0.55, 1.0])
	v.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0.04, 0.0, 0.1, 0.75)])
	var vt := GradientTexture2D.new()
	vt.gradient = v
	vt.fill = GradientTexture2D.FILL_RADIAL
	vt.fill_from = Vector2(0.5, 0.5)
	vt.fill_to = Vector2(0.5, 1.15)
	vt.width = 256
	vt.height = 256
	_vignette.texture = vt
	add_child(_vignette)
	for i in MOTES:
		_motes.append({
			"p": Vector2(randf(), randf()),
			"v": Vector2(randf_range(-0.004, 0.004), randf_range(-0.018, -0.006)),
			"r": randf_range(1.5, 4.5),
			"ph": randf() * TAU,
			"warm": randf() < 0.5,
		})


func _process(delta: float) -> void:
	_time += delta
	for m in _motes:
		m["p"] += m["v"] * delta
		if m["p"].y < -0.05:
			m["p"] = Vector2(randf(), 1.05)
	queue_redraw()


func _draw() -> void:
	var s := size
	for m in _motes:
		var p: Vector2 = m["p"] * s
		p.x += sin(_time * 0.6 + m["ph"]) * 12.0
		var a := 0.25 + 0.25 * sin(_time * 1.7 + m["ph"])
		var c: Color = (UiKit.AMBER if m["warm"] else accent)
		draw_circle(p, m["r"] * 2.6, Color(c, a * 0.18))
		draw_circle(p, m["r"], Color(c.lerp(Color.WHITE, 0.4), a))
	# Scanlines that roll slowly downward.
	var off := fmod(_time * 18.0, 6.0)
	var y := off
	while y < s.y:
		draw_line(Vector2(0, y), Vector2(s.x, y), Color(0, 0, 0, 0.045), 1.0)
		y += 6.0
