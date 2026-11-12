class_name NeonLogo
extends Control
## The "WHAT LIES AHEAD" logo: chunky two-line title with a pink neon glow
## behind it, a sweeping shine, an occasional neon flicker, and a subtitle
## strip. `appear()` animates it in letter by letter.

signal letter_landed(index: int)

const LINES := ["WHAT LIES", "AHEAD"]

var size_px := 150
var subtitle := "AN ARCADE ZOMBIE SURVIVAL"
var _glows: Array[Label] = []
var _letters: Array[Label] = []
var _sub: Label
var _flicker := 0.0
var _next_flicker := 3.0
var _shine: ShaderMaterial
var _flick_index := 0
var _base_y := 0.0
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shine = ShaderMaterial.new()
	_shine.shader = load("res://art/shaders/ui_shine.gdshader")
	_shine.set_shader_parameter("span", size_px * 6.0)
	_shine.set_shader_parameter("height", size_px * 1.1)
	var y := 0.0
	var widest := 0.0
	for line in LINES:
		var x := 0.0
		for ch in line:
			if ch == " ":
				x += size_px * 0.32
				continue
			# Two-layer neon glow: a wide soft halo and a tighter hot rim.
			var halo := UiKit.arcade_label(ch, size_px, Color(UiKit.PINK, 0.0))
			halo.add_theme_color_override("font_outline_color", Color(1.0, 0.25, 0.65, 0.22))
			halo.add_theme_constant_override("outline_size", int(size_px * 0.42))
			halo.add_theme_constant_override("shadow_offset_y", 0)
			var glow := UiKit.arcade_label(ch, size_px, UiKit.PINK)
			glow.add_theme_color_override("font_outline_color", Color(1.0, 0.35, 0.75, 0.75))
			glow.add_theme_constant_override("outline_size", int(size_px * 0.2))
			glow.add_theme_constant_override("shadow_offset_y", 0)
			glow.position = Vector2(x, y)
			glow.add_child(halo)
			halo.position = Vector2.ZERO
			halo.show_behind_parent = true
			add_child(glow)
			_glows.append(glow)
			var l := UiKit.arcade_label(ch, size_px, Color.WHITE)
			l.material = _shine
			l.position = Vector2(x, y)
			add_child(l)
			_letters.append(l)
			x += _advance(ch)
		widest = maxf(widest, x)
		y += size_px * 0.86
	_sub = UiKit.arcade_label(subtitle, int(size_px * 0.26), UiKit.AMBER)
	_sub.position = Vector2(size_px * 0.05, y + size_px * 0.22)
	add_child(_sub)
	custom_minimum_size = Vector2(widest, y + size_px * 0.6)


func _advance(ch: String) -> float:
	var font := UiKit.display_font()
	return font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x * 0.98


## Letters drop in one by one with an overshoot; the glow flashes on after.
func appear(delay := 0.0, step := 0.07) -> void:
	for i in _letters.size():
		var l := _letters[i]
		var g := _glows[i]
		var home := l.position
		l.modulate.a = 0.0
		g.modulate.a = 0.0
		l.position = home + Vector2(0, -size_px * 0.9)
		l.pivot_offset = Vector2(size_px * 0.3, size_px * 0.5)
		var tw := create_tween()
		tw.tween_interval(delay + i * step)
		tw.tween_callback(func(): letter_landed.emit(i))
		tw.set_parallel(true)
		tw.tween_property(l, "position", home, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(l, "modulate:a", 1.0, 0.12)
		tw.chain().tween_property(g, "modulate:a", 1.0, 0.25)
	_sub.modulate.a = 0.0
	var t2 := create_tween()
	t2.tween_interval(delay + _letters.size() * step + 0.25)
	t2.tween_property(_sub, "modulate:a", 1.0, 0.4)


func show_now() -> void:
	for l in _letters:
		l.modulate.a = 1.0
	for g in _glows:
		g.modulate.a = 1.0
	_sub.modulate.a = 1.0


func _process(delta: float) -> void:
	# Neon flicker: every few seconds one letter's glow stutters.
	_next_flicker -= delta
	if _next_flicker <= 0.0:
		_next_flicker = randf_range(2.5, 6.0)
		_flicker = 0.35
		_flick_index = randi() % _glows.size()
	if _flicker > 0.0:
		_flicker -= delta
		var g := _glows[_flick_index]
		g.modulate.a = (0.25 if int(_flicker * 30.0) % 2 == 0 else 1.0) if _flicker > 0.0 else 1.0
	# Gentle hover around the resting position.
	_time += delta
	for c in get_children():
		if c is Control:
			c.position.y += (sin(_time * 1.2) - sin((_time - delta) * 1.2)) * 4.0

