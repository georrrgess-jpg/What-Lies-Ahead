class_name MenuSettings
extends MenuPage
## The menu's Settings page: the options list (SettingsPanel, shared with the
## pause menu) on a signboard that scrolls, and the controls reference on a
## second board beside it. Changes apply at once and are saved on leaving.

var _panel: SettingsPanel
var _scroll: ScrollContainer


func uses_shell_header() -> bool:
	return true


func _ready() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", UiKit.GAP_L)
	add_child(row)
	var board := UiKit.signboard()
	board.custom_minimum_size.x = 1060
	row.add_child(board)
	_scroll = UiKit.scroll()
	board.add_child(_scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_right", UiKit.GAP_L)
	_scroll.add_child(margin)
	_panel = SettingsPanel.new()
	_panel.show_header = false
	_panel.show_controls = false
	_panel.closed.connect(func(): back.emit())
	margin.add_child(_panel)
	var side := UiKit.signboard()
	side.custom_minimum_size.x = 620
	side.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	side.add_child(SettingsPanel.controls_reference())
	row.add_child(side)
	visibility_changed.connect(_on_visibility_changed)


func refresh() -> void:
	# Focus lands on the first option; keep the list at its top all the same.
	_scroll.set_deferred("scroll_vertical", 0)


func first_focus() -> Control:
	return _panel.find_child("FirstFocus", true, false) as Control


## Leaving the page by any route (BACK, a tab, Esc) saves the settings.
func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		Settings.save()
