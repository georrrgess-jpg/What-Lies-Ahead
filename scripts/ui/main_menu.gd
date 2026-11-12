extends Control
## Main menu: Play (world + level select, starter weapon), Armory, Settings.
## The pier itself turns slowly behind the menu.

const PAGES := ["title", "play", "armory", "settings"]

var _pages := {}
var _selected_level: LevelData
var _selected_weapon: StringName
var _level_info: Label
var _start_button: Button
var _weapon_buttons := {}
var _level_buttons := {}
var _backdrop: Node3D
var _camera: Camera3D
var _orbit := 0.0


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().paused = false
	Game.capture_mouse(false)
	_build_backdrop()
	Sfx.play_ambience(&"pier_ambience", -12.0)
	Sfx.play_music(&"boardwalk_loop", -11.0)

	var shade := ColorRect.new()
	shade.color = Color(UiKit.INK, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	_selected_weapon = StringName(String(Profile.data.get("last_weapon", "")))
	if GameData.weapon(_selected_weapon) == null:
		_selected_weapon = GameData.default_weapon_id()

	_pages["title"] = _build_title()
	_pages["play"] = _build_play()
	_pages["armory"] = _build_armory()
	_pages["settings"] = _build_settings()
	for key in _pages:
		add_child(_pages[key])
	_show(Game.menu_page if Game.menu_page in PAGES else "title")
	Game.menu_page = ""

	if Profile.recovered_from_bad_save:
		Profile.recovered_from_bad_save = false
		_toast("Your save file could not be read, so a fresh profile was started. A copy of the old file was kept.")


func _process(delta: float) -> void:
	if _camera:
		# Slow sweep out over the water on the ocean side, looking back at the pier.
		_orbit += delta * 0.05
		var angle := deg_to_rad(78.0 + 34.0 * sin(_orbit))
		var centre := Vector3(-2.0, 3.0, -4.0)
		_camera.position = centre + Vector3(sin(angle) * 31.0, 5.5 + sin(_orbit * 0.6) * 1.2, cos(angle) * 31.0)
		_camera.look_at(centre)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _pages["title"].visible:
		if _pages["settings"].visible:
			Settings.save()
		_show("title")


func _show(page: String) -> void:
	for key in _pages:
		_pages[key].visible = key == page
	if page == "armory":
		_pages["armory"].refresh()
	if page == "play":
		_refresh_play()
	var focus := _pages[page].find_child("FirstFocus", true, false) as Control
	if focus and focus.is_inside_tree():
		focus.grab_focus()


# --- backdrop ----------------------------------------------------------------

func _build_backdrop() -> void:
	var levels := GameData.worlds()[0].levels if not GameData.worlds().is_empty() else []
	if levels.is_empty() or not ResourceLoader.exists(levels[0].scene_path):
		var bg := ColorRect.new()
		bg.color = UiKit.NAVY
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(bg)
		return
	_backdrop = (load(levels[0].scene_path) as PackedScene).instantiate()
	# Scenery only: the menu does not run a level.
	var director := _backdrop.find_child("RunDirector", true, false)
	if director:
		_backdrop.remove_child(director)
		director.queue_free()
	add_child(_backdrop)
	_camera = Camera3D.new()
	_camera.fov = 55.0
	_backdrop.add_child(_camera)
	_camera.make_current()
	_orbit = 0.4


# --- title -------------------------------------------------------------------

func _build_title() -> Control:
	var page := Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	col.offset_left = 130
	col.add_theme_constant_override("separation", 14)
	page.add_child(col)
	var title := UiKit.arcade_label("WHAT LIES\nAHEAD", 170, Color.WHITE)
	title.add_theme_constant_override("line_spacing", -34)
	col.add_child(title)
	var sub := UiKit.arcade_label("WORLD 1  ·  BOARDWALK BREAKOUT", 42, UiKit.AMBER)
	col.add_child(sub)
	col.add_child(UiKit.spacer(26))
	for item in [["PLAY", "play"], ["ARMORY", "armory"], ["SETTINGS", "settings"]]:
		var b := UiKit.button(item[0], 54)
		b.custom_minimum_size = Vector2(460, 100)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.pressed.connect(_show.bind(item[1]))
		if item[1] == "play":
			b.name = "FirstFocus"
		col.add_child(b)
	var quit := UiKit.soft_button("Quit", 32)
	quit.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	quit.custom_minimum_size = Vector2(220, 0)
	quit.pressed.connect(func(): get_tree().quit())
	col.add_child(UiKit.spacer(4))
	col.add_child(quit)
	return page


# --- play --------------------------------------------------------------------

func _page_frame(title_text: String) -> Array:
	var page := Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var title := UiKit.label(title_text, 64, UiKit.AMBER, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var back := UiKit.soft_button("Back", 30)
	back.pressed.connect(_show.bind("title"))
	head.add_child(back)
	return [page, col]


func _build_play() -> Control:
	var frame := _page_frame("PLAY")
	var page: Control = frame[0]
	var col: VBoxContainer = frame[1]
	col.custom_minimum_size = Vector2(1300, 0)

	for world in GameData.worlds():
		var index := GameData.worlds().find(world) + 1
		col.add_child(UiKit.label("WORLD %d  ·  %s" % [index, world.display_name.to_upper()], 36, UiKit.CYAN, true))
		if world.blurb != "":
			var blurb := UiKit.label(world.blurb, 24, UiKit.CREAM)
			blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			col.add_child(blurb)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		col.add_child(row)
		var level_number := 1
		for level in world.levels:
			var b := UiKit.soft_button("", 30)
			b.toggle_mode = true
			b.custom_minimum_size = Vector2(330, 110)
			b.pressed.connect(_select_level.bind(level))
			b.set_meta("number", level_number)
			_style_card(b)
			row.add_child(b)
			_level_buttons[level.id] = b
			level_number += 1
			if _selected_level == null and GameData.is_level_unlocked(level):
				_selected_level = level

	_level_info = UiKit.label("", 26, UiKit.CREAM)
	_level_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_level_info)
	col.add_child(UiKit.spacer(6))

	col.add_child(UiKit.label("CHOOSE YOUR STARTER WEAPON", 36, UiKit.CYAN, true))
	var weapons := HBoxContainer.new()
	weapons.add_theme_constant_override("separation", 16)
	col.add_child(weapons)
	for weapon in GameData.weapons():
		var b := UiKit.soft_button("", 28)
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(420, 190)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_select_weapon.bind(weapon.id))
		_style_card(b)
		weapons.add_child(b)
		_weapon_buttons[weapon.id] = b
	col.add_child(UiKit.label("You can swap weapons for free at the Prize Kiosk between waves.", 22, Color(1, 1, 1, 0.75)))

	col.add_child(UiKit.spacer(4))
	_start_button = UiKit.button("ENTER THE PIER", 56)
	_start_button.name = "FirstFocus"
	_start_button.custom_minimum_size = Vector2(560, 104)
	_start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_start_button.pressed.connect(_start)
	col.add_child(_start_button)
	return page


func _style_card(b: Button) -> void:
	var normal := UiKit.box(Color(UiKit.INK, 0.75), Color(1, 1, 1, 0.15), 18, 3, 16)
	var hover := UiKit.box(Color(UiKit.PURPLE, 0.6), Color(1, 1, 1, 0.4), 18, 3, 16)
	var on := UiKit.box(Color(UiKit.PINK_DARK, 0.9), UiKit.CYAN, 18, 5, 16)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	b.add_theme_stylebox_override("disabled", UiKit.box(Color(UiKit.INK, 0.5), Color(1, 1, 1, 0.08), 18, 3, 16))
	b.add_theme_font_override("font", UiKit.body_font())
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _select_level(level: LevelData) -> void:
	if GameData.is_level_unlocked(level):
		_selected_level = level
	_refresh_play()


func _select_weapon(weapon_id: StringName) -> void:
	_selected_weapon = weapon_id
	_refresh_play()


func _refresh_play() -> void:
	for level_id in _level_buttons:
		var level := GameData.level(level_id)
		var b: Button = _level_buttons[level_id]
		var unlocked := GameData.is_level_unlocked(level)
		b.disabled = not unlocked
		b.set_pressed_no_signal(level == _selected_level)
		var status := GameData.lock_reason(level)
		if unlocked:
			status = "Cleared" if Profile.is_level_completed(level.id) else "Best wave: %d" % Profile.best_wave(level.id)
		b.text = "LEVEL %d\n%s\n%s" % [int(b.get_meta("number")), level.display_name, status]
	for weapon_id in _weapon_buttons:
		var weapon := GameData.weapon(weapon_id)
		var b: Button = _weapon_buttons[weapon_id]
		b.set_pressed_no_signal(weapon_id == _selected_weapon)
		b.text = "%s\n%s\nMagazine %d   ·   %s" % [
			weapon.display_name.to_upper(), weapon.role,
			weapon.magazine_size, UiKit.rank_name(Mastery.rank(weapon_id), weapon.max_rank()).capitalize()]
	if _selected_level:
		var waves := _selected_level.wave_set.waves.size() if _selected_level.wave_set else 0
		_level_info.text = "%s — %s  (%d waves)" % [_selected_level.display_name, _selected_level.blurb, waves]
		_start_button.disabled = false
	else:
		_level_info.text = "No level available."
		_start_button.disabled = true


func _start() -> void:
	if _selected_level == null:
		return
	Profile.save_profile()
	Game.start_level(_selected_level.id, _selected_weapon)


# --- armory / settings -----------------------------------------------------------

func _build_armory() -> Control:
	var armory := ArmoryPage.new()
	armory.back.connect(_show.bind("title"))
	return armory


func _build_settings() -> Control:
	var page := Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var settings := SettingsPanel.new()
	settings.closed.connect(_show.bind("title"))
	panel.add_child(settings)
	return page


func _toast(text: String) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.NAVY, 0.95), UiKit.AMBER, 16, 3, 16))
	var l := UiKit.label(text, 24, UiKit.CREAM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(760, 0)
	panel.add_child(l)
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_bottom = -40
	var tw := panel.create_tween()
	tw.tween_interval(8.0)
	tw.tween_property(panel, "modulate:a", 0.0, 0.8)
	tw.tween_callback(panel.queue_free)
