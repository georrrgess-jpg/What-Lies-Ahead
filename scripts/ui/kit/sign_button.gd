class_name SignButton
extends Button
## The kit's button: a painted fairground sign with a darker lip. It grows a
## little and sends a shine across its face on hover or keyboard focus,
## squashes when pressed, shows a cyan ring while focused and plays the kit's
## sounds. Make one through UiKit (sign_button, back_button, icon_button,
## toggle_button) or SignButton.make().

enum Kind {
	## Pink: the one action a screen is about (PLAY, DEPLOY, EQUIP).
	PRIMARY,
	## Teal: everything else.
	SECONDARY,
	## Gold: spend Sparks, claim a reward.
	GOLD,
	## Purple: quiet actions and the off state of toggles.
	NEUTRAL,
	## Teal plate with pointed ends: BACK.
	BACK,
	## Small dark square holding an icon.
	ICON,
}

const _COLORS := {Kind.PRIMARY: &"pink", Kind.SECONDARY: &"teal", Kind.GOLD: &"gold", Kind.NEUTRAL: &"purple"}

var kind := Kind.PRIMARY
## 0-1 while the shine crosses the face, -1 otherwise.
var shine := -1.0:
	set(v):
		shine = v
		queue_redraw()
var _lifted := false

static var _tab_boxes := {}
var _shine_points := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])


static func make(text_value: String, button_kind := Kind.PRIMARY, font_size := 36) -> SignButton:
	var b := SignButton.new()
	b.text = text_value
	b.kind = button_kind
	b.add_theme_font_size_override("font_size", font_size)
	b._style()
	return b


static func make_icon(icon_name: StringName, tooltip := "") -> SignButton:
	var b := SignButton.new()
	b.kind = Kind.ICON
	b.icon = KitTex.tex(icon_name)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(64, 64)
	b.tooltip_text = tooltip
	b._style()
	return b


static func make_toggle(text_value: String, group: ButtonGroup = null, font_size := 26) -> SignButton:
	var b := make(text_value, Kind.NEUTRAL, font_size)
	b.toggle_mode = true
	b.button_group = group
	b.add_theme_stylebox_override("pressed", KitTex.button(&"btn", &"pink", &"normal"))
	b.add_theme_stylebox_override("hover_pressed", KitTex.button(&"btn", &"pink", &"hover"))
	return b


## A quiet toggle for tab rows that sit on dark bars: dark when off, pink when on.
static func make_tab(text_value: String, group: ButtonGroup = null, font_size := 28) -> SignButton:
	var b := make_toggle(text_value, group, font_size)
	if _tab_boxes.is_empty():
		for state in [&"normal", &"hover"]:
			_tab_boxes[state] = _narrow(KitTex.button(&"btn_icon", &"", state))
			_tab_boxes[StringName("on_" + state)] = _narrow(KitTex.button(&"btn", &"pink", state))
	b.add_theme_stylebox_override("normal", _tab_boxes[&"normal"])
	b.add_theme_stylebox_override("hover", _tab_boxes[&"hover"])
	b.add_theme_stylebox_override("pressed", _tab_boxes[&"on_normal"])
	b.add_theme_stylebox_override("hover_pressed", _tab_boxes[&"on_hover"])
	return b


## A copy of a button box with the side padding of a tab.
static func _narrow(box: StyleBoxTexture) -> StyleBoxTexture:
	var sb: StyleBoxTexture = box.duplicate()
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 10
	sb.content_margin_bottom = 16
	return sb


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_entered.connect(_update_lift.bind(true))
	mouse_exited.connect(_update_lift.bind(false))
	focus_entered.connect(_update_lift.bind(true))
	focus_exited.connect(_update_lift.bind(false))
	button_down.connect(_on_down)
	pressed.connect(_on_pressed)


## Applies the textures and text colours of `kind`.
func _style() -> void:
	var family: StringName = &"btn"
	var color: StringName = _COLORS.get(kind, &"")
	if kind == Kind.BACK:
		family = &"sign_back"
	elif kind == Kind.ICON:
		family = &"btn_icon"
	for state in [&"normal", &"hover", &"pressed"]:
		add_theme_stylebox_override(state, KitTex.button(family, color, state))
	add_theme_stylebox_override("hover_pressed", KitTex.button(family, color, &"pressed"))
	add_theme_stylebox_override("focus", KitTex.box(&"focus_ring"))
	add_theme_stylebox_override("disabled", KitTex.button(family, color, &"normal") if kind == Kind.ICON else KitTex.button(&"btn", &"grey", &"normal"))
	add_theme_font_override("font", UiKit.display_font())
	if kind == Kind.GOLD:
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			add_theme_color_override(c, Color("3a1a08"))
		add_theme_color_override("font_outline_color", Color(1.0, 0.95, 0.75, 0.5))
		add_theme_constant_override("outline_size", 4)
	if kind == Kind.ICON:
		add_theme_constant_override("icon_max_width", 36)


func _update_lift(entering: bool) -> void:
	var want := (is_hovered() or has_focus()) and not disabled
	if want == _lifted:
		return
	_lifted = want
	UiFx.hover(self, want)
	if want and entering:
		UiSound.hover()
		if kind != Kind.ICON:
			shine = 0.0
			var tw := create_tween()
			tw.tween_property(self, "shine", 1.0, 0.32)
			tw.tween_callback(func(): shine = -1.0)


func _on_down() -> void:
	UiFx.squash(self, UiFx.HOVER_SCALE if _lifted else 1.0)


func _on_pressed() -> void:
	if kind == Kind.BACK:
		UiSound.back()
	elif toggle_mode:
		UiSound.tab()
	else:
		UiSound.click()


func _draw() -> void:
	if shine < 0.0 or shine > 1.0:
		return
	var lean := size.y * 0.5
	var x := lerpf(-lean - 30.0, size.x + lean, shine)
	var top := 5.0
	var bottom := size.y - 12.0
	_shine_points[0] = Vector2(clampf(x, 8.0, size.x - 8.0), top)
	_shine_points[1] = Vector2(clampf(x + 30.0, 8.0, size.x - 8.0), top)
	_shine_points[2] = Vector2(clampf(x + 30.0 - lean, 8.0, size.x - 8.0), bottom)
	_shine_points[3] = Vector2(clampf(x - lean, 8.0, size.x - 8.0), bottom)
	if _shine_points[1].x - _shine_points[0].x > 1.0 and _shine_points[2].x - _shine_points[3].x > 1.0:
		draw_colored_polygon(_shine_points, Color(1, 1, 1, 0.2))
