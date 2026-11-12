class_name UiKit
extends RefCounted
## Shared look for menus and the HUD: palette, fonts and a code-built Theme.

const PINK := Color("ff3fa4")
const PINK_LIGHT := Color("ff7cc6")
const PINK_DARK := Color("b81f72")
const CYAN := Color("35f0ff")
const AMBER := Color("ffc24a")
const TEAL := Color("17a3a3")
const NAVY := Color("1b1446")
const INK := Color("120c2e")
const PURPLE := Color("6a34b8")
const CREAM := Color("fff3dc")
const GREEN := Color("52f060")
const RED := Color("ff4d6a")

const DISPLAY_FONT_PATH := "res://art/fonts/LilitaOne-Regular.ttf"
const BODY_FONT_PATH := "res://art/fonts/Baloo2-Variable.ttf"

static var _theme: Theme
static var _display: Font
static var _body: Font


static func display_font() -> Font:
	if _display == null:
		_display = load(DISPLAY_FONT_PATH) if ResourceLoader.exists(DISPLAY_FONT_PATH) else ThemeDB.fallback_font
	return _display


static func body_font() -> Font:
	if _body == null:
		if ResourceLoader.exists(BODY_FONT_PATH):
			var variation := FontVariation.new()
			variation.base_font = load(BODY_FONT_PATH)
			variation.variation_opentype = {"wght": 650}
			_body = variation
		else:
			_body = ThemeDB.fallback_font
	return _body


static func box(fill: Color, border := Color.TRANSPARENT, radius := 18, border_width := 0, padding := 18) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(padding)
	sb.anti_aliasing = true
	return sb


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 28

	# Buttons: chunky pink pills with a darker lip.
	var normal := box(PINK, PINK_DARK, 22, 0, 16)
	normal.border_width_bottom = 8
	normal.content_margin_left = 34
	normal.content_margin_right = 34
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = PINK_LIGHT
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = PINK_DARK
	pressed.border_width_bottom = 2
	pressed.content_margin_top = 22
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color(0.35, 0.3, 0.5)
	disabled.border_color = Color(0.22, 0.18, 0.36)
	var focus := box(Color.TRANSPARENT, CYAN, 24, 4, 0)
	focus.expand_margin_left = 4
	focus.expand_margin_right = 4
	focus.expand_margin_top = 4
	focus.expand_margin_bottom = 4
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", focus)
	t.set_font("font", "Button", display_font())
	t.set_font_size("font_size", "Button", 38)
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", CREAM)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.45))

	t.set_stylebox("panel", "PanelContainer", box(Color(NAVY, 0.92), PINK, 26, 4, 28))
	t.set_stylebox("panel", "Panel", box(Color(NAVY, 0.92), PINK, 26, 4, 28))
	t.set_color("font_color", "Label", Color.WHITE)
	t.set_color("font_shadow_color", "Label", Color(INK, 0.7))
	t.set_constant("shadow_offset_y", "Label", 3)
	t.set_constant("shadow_offset_x", "Label", 0)

	# Sliders.
	var track := box(Color(INK, 0.9), Color.TRANSPARENT, 8, 0, 0)
	track.content_margin_top = 8
	track.content_margin_bottom = 8
	var fill := box(CYAN, Color.TRANSPARENT, 8, 0, 0)
	fill.content_margin_top = 8
	fill.content_margin_bottom = 8
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var knob := _circle_texture(18, Color.WHITE, PINK)
	t.set_icon("grabber", "HSlider", knob)
	t.set_icon("grabber_highlight", "HSlider", _circle_texture(18, CREAM, CYAN))

	t.set_stylebox("panel", "TooltipPanel", box(INK, CYAN, 10, 2, 10))
	_theme = t
	return t


static func _circle_texture(radius: int, fill: Color, ring: Color) -> ImageTexture:
	var size := radius * 2 + 2
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size / 2.0, size / 2.0)
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var col := Color.TRANSPARENT
			if d <= radius:
				col = ring if d > radius - 5 else fill
				col.a = clampf(radius - d + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


static func label(text: String, size := 28, color := Color.WHITE, display := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if display:
		l.add_theme_font_override("font", display_font())
	return l


## Big arcade text: display font with a dark outline, like the reference HUD.
static func arcade_label(text: String, size := 72, color := Color.WHITE) -> Label:
	var l := label(text, size, color, true)
	l.add_theme_color_override("font_outline_color", Color(INK, 0.85))
	l.add_theme_constant_override("outline_size", maxi(6, size / 7))
	l.add_theme_constant_override("shadow_offset_y", maxi(3, size / 16))
	return l


static func button(text: String, font_size := 38) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_entered.connect(func(): if not b.disabled: Sfx.play(&"ui_hover", -14.0))
	b.pressed.connect(func(): Sfx.play(&"ui_click", -6.0))
	return b


## Secondary (teal) button style.
static func soft_button(text: String, font_size := 30) -> Button:
	var b := button(text, font_size)
	var normal := box(Color(TEAL, 0.95), Color("0d6f73"), 18, 0, 10)
	normal.border_width_bottom = 6
	normal.content_margin_left = 24
	normal.content_margin_right = 24
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color("25c4c4")
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color("0d6f73")
	pressed.border_width_bottom = 2
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	return b


static func spacer(height := 16.0, width := 0.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(width, height)
	return c


## XP bar: dark track with a cyan fill. Returns the ProgressBar.
static func progress(value: float, height := 18.0, fill_color := CYAN) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, height)
	bar.add_theme_stylebox_override("background", box(Color(INK, 0.9), Color.TRANSPARENT, int(height / 2), 0, 0))
	bar.add_theme_stylebox_override("fill", box(fill_color, Color.TRANSPARENT, int(height / 2), 0, 0))
	return bar


static func rank_name(rank: int, max_rank: int) -> String:
	if rank >= max_rank:
		return "MASTERED"
	return "RANK %d" % rank
