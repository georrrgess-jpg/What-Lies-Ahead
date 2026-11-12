class_name SettingsPanel
extends VBoxContainer
## Options list used by both the main menu and the pause menu. Changes apply
## immediately and are saved when the panel is closed.
##
## `header` (the title with BACK at the top right, like every other page) is
## made up front so a host can pin it above the scrolling list; if the host
## does not place it, the panel puts it at its own top.

signal closed

## Title row with the BACK button.
var header: Control

var _rows := {}


func _init() -> void:
	header = _build_header()


func _build_header() -> Control:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	var title := UiKit.label("SETTINGS", 64, UiKit.AMBER, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var back := UiKit.soft_button("BACK", 30)
	back.custom_minimum_size = Vector2(170, 56)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(close)
	head.add_child(back)
	return head


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	custom_minimum_size = Vector2(880, 0)
	if header.get_parent() == null:
		add_child(header)

	_section("CONTROLS")
	_slider("look_sensitivity", "Look sensitivity", Settings.LOOK_RANGE.x, Settings.LOOK_RANGE.y, 0.05, func(v): return "%.2f" % v)
	_slider("ads_sensitivity", "Aim sensitivity", 0.3, 1.5, 0.05, func(v): return "%.2f" % v)
	_slider("fov", "Field of view (vertical)", 60.0, 100.0, 1.0, _fov_text)
	_section("RETICLE")
	_choice("reticle_style", "Style", [["auto", "Auto"], ["cross", "Cross"], ["circle", "Circle"], ["dot", "Dot"], ["chevron", "Chevron"]])
	_choice("reticle_color", "Colour", [["white", "White"], ["cyan", "Cyan"], ["pink", "Pink"], ["green", "Green"], ["yellow", "Yellow"]])
	_section("AUDIO")
	_slider("master_volume", "Master volume", 0.0, 1.0, 0.05, _percent)
	_slider("music_volume", "Music volume", 0.0, 1.0, 0.05, _percent)
	_slider("sfx_volume", "Effects volume", 0.0, 1.0, 0.05, _percent)
	_section("COMFORT")
	_slider("camera_motion", "Camera motion", 0.0, 1.0, 0.05, _percent)
	_slider("camera_shake", "Camera shake", 0.0, 1.0, 0.05, _percent)
	_slider("flashes", "Flashes", 0.0, 1.0, 0.05, _percent)
	_section("DISPLAY")
	_choice("graphics", "Graphics", [["high", "High"], ["low", "Low"]])
	_choice("fullscreen", "Window", [[false, "Windowed"], [true, "Fullscreen"]])

	_add_menu_pass_rows()

	add_child(UiKit.spacer(10))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	add_child(buttons)
	var reset := UiKit.soft_button("RESET TO DEFAULTS")
	reset.pressed.connect(func():
		Settings.reset_to_defaults()
		_refresh())
	buttons.add_child(reset)
	# Keyboard and gamepad focus starts on the first option.
	var sliders := find_children("*", "HSlider", true, false)
	if not sliders.is_empty():
		sliders[0].name = "FirstFocus"


## Invert Y (under Controls) and ambience volume (under Audio). Each row
## moves to just after its neighbour; with no neighbour it stays at the end.
func _add_menu_pass_rows() -> void:
	_choice("invert_y", "Invert look Y", [[false, "Off"], [true, "On"]])
	_place_after(_rows["invert_y"]["buttons"][0]["button"].get_parent(), "ads_sensitivity")
	_slider("ambience_volume", "Ambience volume", 0.0, 1.0, 0.05, _percent)
	_place_after(_rows["ambience_volume"]["slider"].get_parent(), "sfx_volume")


func _place_after(row: Control, neighbour_key: String) -> void:
	var entry: Dictionary = _rows.get(neighbour_key, {})
	if entry.has("slider"):
		move_child(row, (entry["slider"] as Control).get_parent().get_index() + 1)


func close() -> void:
	Settings.save()
	closed.emit()


func _percent(v: float) -> String:
	return "%d%%" % int(round(v * 100.0))


## The FOV setting is vertical; also show what that spans across a 16:9 screen.
func _fov_text(v: float) -> String:
	var wide := rad_to_deg(2.0 * atan(tan(deg_to_rad(v) * 0.5) * 16.0 / 9.0))
	return "%d° (%d° wide)" % [int(v), int(round(wide))]


func _section(text: String) -> void:
	add_child(UiKit.spacer(4))
	add_child(UiKit.label(text, 26, UiKit.CYAN, true))


func _row(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	var l := UiKit.label(text, 28)
	l.custom_minimum_size = Vector2(320, 0)
	row.add_child(l)
	add_child(row)
	return row


func _slider(key: String, text: String, min_v: float, max_v: float, step: float, format: Callable) -> void:
	var row := _row(text)
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = float(Settings.value(key))
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(360, 36)
	row.add_child(slider)
	var value := UiKit.label(format.call(slider.value), 28, UiKit.CREAM)
	value.custom_minimum_size = Vector2(100, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	slider.value_changed.connect(func(v: float):
		Settings.set_value(key, v)
		value.text = format.call(v))
	_rows[key] = {"slider": slider, "label": value, "format": format}


func _choice(key: String, text: String, options: Array) -> void:
	var row := _row(text)
	var group := ButtonGroup.new()
	var buttons := []
	for option in options:
		var b := UiKit.soft_button(option[1], 26)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = Settings.value(key) == option[0]
		_style_toggle(b)
		b.pressed.connect(func(): Settings.set_value(key, option[0]))
		row.add_child(b)
		buttons.append({"button": b, "value": option[0]})
	_rows[key] = {"buttons": buttons}


func _style_toggle(b: Button) -> void:
	var on := UiKit.box(UiKit.PINK, UiKit.PINK_DARK, 18, 0, 10)
	on.border_width_bottom = 6
	on.content_margin_left = 24
	on.content_margin_right = 24
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)


func _refresh() -> void:
	for key in _rows:
		var entry: Dictionary = _rows[key]
		if entry.has("slider"):
			entry["slider"].set_value_no_signal(float(Settings.value(key)))
			entry["label"].text = entry["format"].call(float(Settings.value(key)))
		else:
			for item in entry["buttons"]:
				item["button"].set_pressed_no_signal(Settings.value(key) == item["value"])
