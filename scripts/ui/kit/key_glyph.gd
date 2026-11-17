class_name KeyGlyph
extends RefCounted
## Key prompts: a cream keycap with the key's name, or a mouse with the
## button lit for "LMB" / "RMB".
##
##   row.add_child(UiKit.key_prompt("ESC", "Back"))
##   row.add_child(UiKit.key_prompt("LMB", "Select"))
##   label_row.add_child(UiKit.key_glyph("E", 48.0))

const MOUSE := {"LMB": &"icon_mouse_l", "RMB": &"icon_mouse_r"}
## Pad button names on a keycap (the layout is GamepadInput.LAYOUT).
const PAD_BUTTONS := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_START: "START", JOY_BUTTON_BACK: "BACK",
	JOY_BUTTON_DPAD_UP: "UP", JOY_BUTTON_DPAD_DOWN: "DOWN", JOY_BUTTON_DPAD_LEFT: "LEFT", JOY_BUTTON_DPAD_RIGHT: "RIGHT",
}
const PAD_AXES := {
	JOY_AXIS_LEFT_X: "L STICK", JOY_AXIS_LEFT_Y: "L STICK", JOY_AXIS_RIGHT_X: "R STICK", JOY_AXIS_RIGHT_Y: "R STICK",
	JOY_AXIS_TRIGGER_LEFT: "LT", JOY_AXIS_TRIGGER_RIGHT: "RT",
}
## Keycaps are never smaller than this (their corners need the room).
const MIN_SIZE := 44.0


## A keycap `glyph_size` pixels tall (wider for long names such as "SPACE").
static func make(key: String, glyph_size := 44.0) -> Control:
	if MOUSE.has(key):
		return UiKit.icon(MOUSE[key], glyph_size)
	glyph_size = maxf(glyph_size, MIN_SIZE)
	var cap := PanelContainer.new()
	var sb: StyleBoxTexture = KitTex.box_copy(&"keycap")
	sb.content_margin_left = glyph_size * 0.28
	sb.content_margin_right = glyph_size * 0.28
	sb.content_margin_top = 0
	sb.content_margin_bottom = glyph_size * 0.16
	cap.add_theme_stylebox_override("panel", sb)
	cap.custom_minimum_size = Vector2(glyph_size, glyph_size)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiKit.label(key, int(glyph_size * 0.42), UiKit.INK, true)
	l.add_theme_constant_override("shadow_offset_y", 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_child(l)
	return cap


## A keycap followed by what the key does.
static func prompt(key: String, action: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiKit.GAP_S)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(make(key))
	var l := UiKit.label(action, 22, UiKit.CREAM)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)
	return row


## What an in-game prompt for `action` shows on its keycap: the pad button
## while the last input came from a pad (and the action has one), else
## `keyboard`, or the action's first key ("Escape" becomes "ESC") when empty.
static func action_key(action: StringName, keyboard := "") -> String:
	if GamepadInput.in_use:
		var pad := pad_name(action)
		if pad != "":
			return pad
	if keyboard != "":
		return keyboard
	var key := Loadout.key_hint(action).get_slice(" / ", 0)
	return "ESC" if key == "Escape" else key.to_upper()


## The pad button or stick bound to `action` ("" when none).
static func pad_name(action: StringName) -> String:
	if not InputMap.has_action(action):
		return ""
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and PAD_BUTTONS.has((event as InputEventJoypadButton).button_index):
			return PAD_BUTTONS[(event as InputEventJoypadButton).button_index]
		if event is InputEventJoypadMotion and PAD_AXES.has((event as InputEventJoypadMotion).axis):
			return PAD_AXES[(event as InputEventJoypadMotion).axis]
	return ""
