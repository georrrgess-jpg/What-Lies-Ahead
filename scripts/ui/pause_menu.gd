extends CanvasLayer
## Pause overlay. Frees the mouse while open and recaptures it on resume.

var _director: RunDirector
var _root: Control
var _main: Control
var _settings: SettingsPanel
var _settings_scroll: ScrollContainer
var _resume_button: Button


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS


func open(director: RunDirector) -> void:
	_director = director
	get_tree().paused = true
	Game.capture_mouse(false)
	_root = Control.new()
	_root.theme = UiKit.theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(UiKit.INK, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	_main = VBoxContainer.new()
	_main.add_theme_constant_override("separation", 18)
	panel.add_child(_main)
	var title := UiKit.label("PAUSED", 80, UiKit.AMBER, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main.add_child(title)
	var sub := UiKit.label("%s  ·  Wave %d of %d" % [director.level.display_name, maxi(1, director.wave_number), director.total_waves()], 28, UiKit.CREAM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main.add_child(sub)
	_main.add_child(UiKit.spacer(6))
	var resume := UiKit.button("Resume")
	resume.custom_minimum_size = Vector2(460, 0)
	resume.pressed.connect(_resume)
	_resume_button = resume
	_main.add_child(resume)
	var settings := UiKit.soft_button("Settings", 34)
	settings.pressed.connect(_open_settings)
	_main.add_child(settings)
	var restart := UiKit.soft_button("Restart run", 34)
	restart.pressed.connect(func(): _leave(true))
	_main.add_child(restart)
	var menu := UiKit.soft_button("Main menu", 34)
	menu.pressed.connect(func(): _leave(false))
	_main.add_child(menu)
	var note := UiKit.label("Mastery earned so far is kept.", 22, Color(1, 1, 1, 0.7))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main.add_child(note)

	# Settings scroll like on the main menu, so they fit any window height.
	_settings_scroll = ScrollContainer.new()
	_settings_scroll.custom_minimum_size = Vector2(960, 860)
	_settings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_settings_scroll.visible = false
	panel.add_child(_settings_scroll)
	_settings = SettingsPanel.new()
	_settings.closed.connect(_close_settings)
	_settings_scroll.add_child(_settings)
	resume.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if _settings_scroll and _settings_scroll.visible:
			_settings.close()
		else:
			_resume()


func _open_settings() -> void:
	_main.visible = false
	_settings_scroll.visible = true
	var first := _settings.find_child("FirstFocus", true, false) as Control
	if first:
		first.grab_focus()


func _close_settings() -> void:
	_settings_scroll.visible = false
	_main.visible = true
	_resume_button.grab_focus()


func _resume() -> void:
	get_tree().paused = false
	Game.capture_mouse(true)
	queue_free()


func _leave(retry: bool) -> void:
	get_tree().paused = false
	_director.abandon(retry)
