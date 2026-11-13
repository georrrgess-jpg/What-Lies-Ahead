extends CanvasLayer
## Pause overlay. Frees the mouse while open and recaptures it on resume.
## Restart and Main menu ask for confirmation first; Settings opens in place
## with BACK at the top right, like every other page.

var _director: RunDirector
var _root: Control
var _main: Control
var _confirm: VBoxContainer
var _settings: SettingsPanel
var _settings_page: Control
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
	var resume := UiKit.button("RESUME")
	resume.custom_minimum_size = Vector2(460, 0)
	resume.pressed.connect(_resume)
	_resume_button = resume
	_main.add_child(resume)
	var settings := UiKit.soft_button("SETTINGS", 34)
	settings.pressed.connect(_open_settings)
	_main.add_child(settings)
	var restart := UiKit.soft_button("RESTART RUN", 34)
	restart.pressed.connect(_ask.bind("RESTART THE RUN?", "This run starts over from the first wave.", "RESTART", _leave.bind(true)))
	_main.add_child(restart)
	if director.has_method("skip_tutorial"):
		var skip := UiKit.soft_button("SKIP TUTORIAL", 34)
		skip.name = "SkipTutorial"
		skip.pressed.connect(_ask.bind("SKIP BOOT CAMP?", "You go to the main menu. Replay it any time from the title screen.", "SKIP", func():
			get_tree().paused = false
			director.skip_tutorial()))
		_main.add_child(skip)
	var menu := UiKit.soft_button("MAIN MENU", 34)
	menu.pressed.connect(_ask.bind("LEAVE THE RUN?", "You go back to the main menu.", "LEAVE", _leave.bind(false)))
	_main.add_child(menu)
	var note := UiKit.label("XP and mastery earned so far are kept.", 22, Color(1, 1, 1, 0.7))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main.add_child(note)

	_confirm = VBoxContainer.new()
	_confirm.add_theme_constant_override("separation", 18)
	_confirm.custom_minimum_size = Vector2(460, 0)
	_confirm.visible = false
	panel.add_child(_confirm)

	# Settings: the header stays pinned above the scrolling list, so BACK is
	# always at the top right.
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	page.visible = false
	panel.add_child(page)
	_settings_page = page
	_settings = SettingsPanel.new()
	_settings.closed.connect(_close_settings)
	page.add_child(_settings.header)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(960, 780)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	scroll.add_child(_settings)
	resume.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if _settings_page and _settings_page.visible:
			_settings.close()
		elif _confirm and _confirm.visible:
			_cancel_confirm()
		else:
			_resume()


## Swaps the menu for a yes / no question; `action` runs on yes.
func _ask(question: String, detail: String, yes_text: String, action: Callable) -> void:
	for c in _confirm.get_children():
		c.queue_free()
	var title := UiKit.label(question, 56, UiKit.AMBER, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm.add_child(title)
	var info := UiKit.label(detail + "\nXP and mastery earned so far are kept.", 26, UiKit.CREAM)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm.add_child(info)
	_confirm.add_child(UiKit.spacer(6))
	var yes := UiKit.button(yes_text)
	yes.pressed.connect(action)
	_confirm.add_child(yes)
	var no := UiKit.soft_button("CANCEL", 34)
	no.pressed.connect(_cancel_confirm)
	_confirm.add_child(no)
	_main.visible = false
	_confirm.visible = true
	# The safe answer has focus, so a stray Enter does not end the run.
	no.grab_focus.call_deferred()


func _cancel_confirm() -> void:
	_confirm.visible = false
	_main.visible = true
	_resume_button.grab_focus()


func _open_settings() -> void:
	_main.visible = false
	_settings_page.visible = true
	var first := _settings_page.find_child("FirstFocus", true, false) as Control
	if first:
		first.grab_focus()


func _close_settings() -> void:
	_settings_page.visible = false
	_main.visible = true
	_resume_button.grab_focus()


func _resume() -> void:
	get_tree().paused = false
	Game.capture_mouse(true)
	queue_free()


func _leave(retry: bool) -> void:
	get_tree().paused = false
	_director.abandon(retry)
