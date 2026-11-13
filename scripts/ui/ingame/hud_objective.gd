class_name HudObjective
extends PanelContainer
## The HUD's objective line (top centre): a slim dark pill with an icon,
## what to do now ("CLEAR THE WAVE", "REACH THE PORTAL"), an optional value
## chip (a countdown, a distance) and an optional key prompt ("F  Start now").
## It pops when the objective changes and costs nothing in between.

var _box: StyleBoxFlat
var _icon: HudIcon
var _text: Label
var _value: Label
var _prompt: HBoxContainer
var _prompt_text: Label
var _key: Label
var _shown_text := ""
var _shown_value := ""
var _shown_prompt := ""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box = UiKit.box(Color(UiKit.INK, 0.72), Color(UiKit.CYAN, 0.9), 30, 2, 0)
	_box.content_margin_left = 22
	_box.content_margin_right = 22
	_box.content_margin_top = 5
	_box.content_margin_bottom = 7
	add_theme_stylebox_override("panel", _box)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	add_child(row)
	_icon = HudIcon.make(&"zombie", 30.0, UiKit.CYAN)
	row.add_child(_icon)
	_text = UiKit.label("", 30, Color.WHITE, true)
	_text.add_theme_constant_override("shadow_offset_y", 2)
	row.add_child(_text)
	_value = UiKit.label("", 30, UiKit.CYAN, true)
	_value.add_theme_constant_override("shadow_offset_y", 2)
	_value.visible = false
	row.add_child(_value)
	_prompt = HBoxContainer.new()
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.add_theme_constant_override("separation", 8)
	_prompt.visible = false
	row.add_child(_prompt)
	var cap := UiKit.key_glyph("F", 44.0)
	_key = cap.get_child(0) as Label
	_prompt.add_child(cap)
	_prompt_text = UiKit.label("", 24, UiKit.CREAM)
	_prompt.add_child(_prompt_text)


## Sets the objective. `value` is the chip after the text ("0:18", "34 m");
## `key` and `prompt` add a key cap and what it does. Empty parts are hidden.
func set_objective(icon: StringName, text: String, accent := UiKit.CYAN, value := "", key := "", prompt := "") -> void:
	if value != _shown_value:
		_shown_value = value
		_value.text = value
		_value.visible = value != ""
	var prompt_key := key + prompt
	if prompt_key != _shown_prompt:
		_shown_prompt = prompt_key
		_prompt.visible = key != ""
		_key.text = key
		_prompt_text.text = prompt
	if text == _shown_text:
		return
	_shown_text = text
	_text.text = text
	_icon.kind = icon
	_icon.color = accent
	_value.add_theme_color_override("font_color", accent)
	_box.border_color = Color(accent, 0.9)
	visible = text != ""
	if is_visible_in_tree():
		UiFx.pulse(self, 1.08)
