class_name MenuButtonFx
extends Button
## Chunky menu button with life: a coloured pill with a darker lip, which on
## hover/focus grows slightly, gets a bright outline and sends a shine sweep
## across its face; pressing squashes it. Sounds come from UiKit.button rules.

var accent := UiKit.PINK
var _hover := 0.0
var _shine := -1.0
var _ring := StyleBoxFlat.new()


static func make(text_value: String, color: Color, font_size: int, min_size: Vector2) -> MenuButtonFx:
	var b := MenuButtonFx.new()
	b.text = text_value
	b.accent = color
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_font_override("font", UiKit.display_font())
	b.focus_mode = Control.FOCUS_ALL
	b._style()
	b.mouse_entered.connect(b._on_hover_start)
	b.focus_entered.connect(b._on_hover_start)
	b.pressed.connect(func(): Sfx.play(&"ui_click", -6.0))
	return b


func _style() -> void:
	var lip := accent.darkened(0.35)
	var normal := UiKit.box(accent, lip, 20, 0, 12)
	normal.border_width_bottom = 7
	normal.content_margin_left = 26
	normal.content_margin_right = 26
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = accent.lightened(0.18)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = lip
	pressed.border_width_bottom = 2
	pressed.content_margin_top = 17
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color(0.32, 0.28, 0.45)
	disabled.border_color = Color(0.2, 0.17, 0.3)
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", pressed)
	add_theme_stylebox_override("disabled", disabled)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	add_theme_color_override("font_color", Color.WHITE)
	add_theme_color_override("font_hover_color", Color.WHITE)
	add_theme_color_override("font_focus_color", Color.WHITE)
	add_theme_color_override("font_outline_color", Color(UiKit.INK, 0.6))
	add_theme_constant_override("outline_size", 8)


func _on_hover_start() -> void:
	if disabled:
		return
	_shine = 0.0
	Sfx.play(&"ui_hover", -14.0)


func _process(delta: float) -> void:
	var want := 1.0 if (is_hovered() or has_focus()) and not disabled else 0.0
	_hover = move_toward(_hover, want, delta * 7.0)
	if _shine >= 0.0:
		_shine += delta * 2.2
		if _shine > 1.4:
			_shine = -1.0
	pivot_offset = size * 0.5
	var k := 1.0 + 0.04 * ease(_hover, -2.0)
	scale = Vector2(k, k) if not button_pressed else Vector2(0.97, 0.97)
	queue_redraw()


func _draw() -> void:
	if _hover > 0.01:
		var r := Rect2(Vector2(-4, -4), size + Vector2(8, 8))
		var sb := _ring
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = Color(1, 1, 1, 0.85 * _hover)
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(24)
		draw_style_box(sb, r)
	if _shine >= 0.0 and _shine <= 1.0:
		var x := lerpf(-size.y, size.x + size.y, _shine)
		var pts := PackedVector2Array([Vector2(x, 4), Vector2(x + 26, 4), Vector2(x + 26 - size.y * 0.5, size.y - 8), Vector2(x - size.y * 0.5, size.y - 8)])
		draw_colored_polygon(pts, Color(1, 1, 1, 0.22))
