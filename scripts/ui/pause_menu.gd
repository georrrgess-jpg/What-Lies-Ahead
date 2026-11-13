extends CanvasLayer
## Pause overlay in the kit's look: a PAUSED marquee, the actions on the left
## (RESUME first), and on the right a signboard with the run so far: level,
## wave, the current objective and the stats. CONTROLS swaps that board for
## the key reference; SETTINGS opens the shared SettingsPanel in place.
## Restart and Main menu ask first (kit dialog, focus on the safe answer).
## Frees the mouse while open and recaptures it on resume.

const BOARD_WIDTH := 640.0

var _director: RunDirector
var _root: Control
var _main: Control
var _info: Control
var _controls: Control
var _controls_button: SignButton
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
	UiKit.apply(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(UiKit.INK, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	_main = VBoxContainer.new()
	_main.add_theme_constant_override("separation", UiKit.GAP_L)
	center.add_child(_main)
	var sign := UiKit.marquee("PAUSED", 72)
	sign.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_main.add_child(sign)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiKit.GAP_L)
	_main.add_child(row)
	row.add_child(_actions())
	# A stack: both boards fill it, it is as tall as the taller one.
	var right := MarginContainer.new()
	right.custom_minimum_size = Vector2(BOARD_WIDTH, 0)
	row.add_child(right)
	_info = _run_board()
	right.add_child(_info)
	_controls = _controls_board()
	_controls.visible = false
	right.add_child(_controls)
	_build_settings(center)
	UiSound.open()
	UiFx.fade_in(dim, 0.15)
	UiFx.stagger_in([sign, row], 0.0, 0.06)
	_resume_button.grab_focus.call_deferred()


## The buttons, primary first, on a metal plate.
func _actions() -> Control:
	var tray := UiKit.metal_frame()
	tray.set_padding(30, 30)
	tray.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiKit.GAP_M)
	tray.add_child(col)
	_resume_button = _button(col, "RESUME", SignButton.Kind.PRIMARY, _resume)
	_resume_button.name = "FirstFocus"
	_button(col, "SETTINGS", SignButton.Kind.SECONDARY, _open_settings)
	_controls_button = _button(col, "CONTROLS", SignButton.Kind.SECONDARY, _toggle_controls)
	_button(col, "RESTART RUN", SignButton.Kind.NEUTRAL, func():
		UiKit.confirm(_root, "RESTART THE RUN?", "This run starts over from the first wave. XP and mastery earned so far are kept.", "RESTART", _leave.bind(true)))
	_button(col, "MAIN MENU", SignButton.Kind.NEUTRAL, func():
		UiKit.confirm(_root, "LEAVE THE RUN?", "You go back to the main menu. XP and mastery earned so far are kept.", "LEAVE", _leave.bind(false)))
	return tray


func _button(col: VBoxContainer, text: String, kind: SignButton.Kind, action: Callable) -> SignButton:
	var b := UiKit.sign_button(text, kind, 40 if kind == SignButton.Kind.PRIMARY else UiKit.SIZE_BUTTON)
	b.custom_minimum_size = Vector2(420, 82 if kind == SignButton.Kind.PRIMARY else 72)
	b.pressed.connect(action)
	col.add_child(b)
	return b


## Level, wave, objective and the run's numbers so far.
func _run_board() -> Control:
	var board := UiKit.signboard()
	board.set_padding(34, 26)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiKit.GAP_S)
	board.add_child(col)
	var level := _director.level
	var world_line := "WORLD %d  ·  %s" % [GameData.worlds().find(level.world) + 1, level.world.display_name.to_upper()] if level.world else ""
	col.add_child(UiKit.label(world_line, UiKit.SIZE_LABEL, UiKit.CYAN, true))
	col.add_child(UiKit.sign_label(level.display_name.to_upper(), UiKit.SIZE_TITLE))
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", UiKit.GAP_S)
	col.add_child(chips)
	chips.add_child(UiKit.chip("WAVE %d OF %d" % [maxi(1, _director.wave_number), _director.total_waves()], UiKit.CYAN, 22))
	chips.add_child(UiKit.chip(Difficulty.label(Difficulty.current()), UiKit.AMBER, 22))
	var objective := String(_director.hud.objective_text()) if _director.hud and _director.hud.has_method("objective_text") else ""
	if objective != "":
		col.add_child(UiKit.spacer(UiKit.GAP_XS))
		col.add_child(UiKit.section("OBJECTIVE"))
		col.add_child(UiKit.label(objective, 30, Color.WHITE, true))
	col.add_child(UiKit.spacer(UiKit.GAP_XS))
	col.add_child(UiKit.section("THIS RUN"))
	var secs := int(_director.elapsed)
	var score: ScoreKeeper = _director.score
	col.add_child(UiKit.stat_row("SCORE", Wallet.format(score.score if score else 0)))
	col.add_child(UiKit.stat_row("KILLS", Wallet.format(_director.total_kills)))
	col.add_child(UiKit.stat_row("BEST COMBO", "x%d" % (score.best_combo if score else 0)))
	col.add_child(UiKit.stat_row("TICKETS", str(_director.tickets)))
	col.add_child(UiKit.stat_row("TIME", "%d:%02d" % [secs / 60, secs % 60]))
	return board


## The key reference, shown in place of the run board.
func _controls_board() -> Control:
	var board := UiKit.signboard()
	board.set_padding(34, 26)
	board.add_child(SettingsPanel.controls_reference())
	return board


## Settings: the header stays pinned above the scrolling list, so BACK is
## always at the top right.
func _build_settings(center: CenterContainer) -> void:
	var board := UiKit.signboard()
	board.set_padding(34, 26)
	board.visible = false
	center.add_child(board)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", UiKit.GAP_M)
	board.add_child(page)
	_settings_page = board
	_settings = SettingsPanel.new()
	_settings.closed.connect(_close_settings)
	page.add_child(_settings.header)
	var scroll := UiKit.scroll(Vector2(960, 760))
	page.add_child(scroll)
	scroll.add_child(_settings)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause") or KitDialog.open_count > 0:
		return
	get_viewport().set_input_as_handled()
	if _settings_page.visible:
		_settings.close()
	elif _controls.visible:
		_toggle_controls()
	else:
		_resume()


func _toggle_controls() -> void:
	var show := not _controls.visible
	_controls.visible = show
	_info.visible = not show
	_controls_button.text = "RUN INFO" if show else "CONTROLS"
	UiFx.pop_in(_controls if show else _info)


func _open_settings() -> void:
	_main.visible = false
	_settings_page.visible = true
	UiFx.pop_in(_settings_page)
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
