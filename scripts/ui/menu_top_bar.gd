class_name MenuTopBar
extends Control
## The menu shell's top bar, always on screen: home and the game's name, one
## tab per section, then the player (level, title, XP), the Sparks balance,
## settings and quit. Drawn as a dark strip on a riveted teal rail.

signal home_pressed
signal tab_pressed(id: String)
signal player_pressed
signal settings_pressed
signal quit_pressed

const RAIL := 10.0

var _tabs: KitTabs
var _home: SignButton
var _wordmark: Label
var _title: Label
var _xp: ProgressBar
var _settings: SignButton


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	custom_minimum_size.y = MenuPage.TOP_BAR
	offset_bottom = MenuPage.TOP_BAR
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 26
	row.offset_right = -26
	row.offset_top = 6
	row.offset_bottom = -RAIL - 4
	row.add_theme_constant_override("separation", UiKit.GAP_M)
	add_child(row)
	_home = UiKit.icon_button(&"icon_home", "Home")
	_home.pressed.connect(func(): home_pressed.emit())
	row.add_child(_home)
	_wordmark = UiKit.sign_label("WHAT LIES AHEAD", 30)
	_wordmark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_wordmark)
	row.add_child(UiKit.spacer(0, UiKit.GAP_S))
	_tabs = KitTabs.make(28, true)
	_tabs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tabs.tab_changed.connect(func(id: StringName): tab_pressed.emit(String(id)))
	row.add_child(_tabs)
	row.add_child(UiKit.filler())
	row.add_child(_player_strip())
	row.add_child(UiKit.sparks_chip())
	_settings = UiKit.icon_button(&"icon_gear", "Settings")
	_settings.pressed.connect(func(): settings_pressed.emit())
	row.add_child(_settings)
	var quit := UiKit.icon_button(&"icon_power", "Quit")
	quit.pressed.connect(func(): quit_pressed.emit())
	row.add_child(quit)


## Adds a section tab (in call order).
func add_tab(id: String, text: String) -> void:
	_tabs.add_tab(StringName(id), text.to_upper())
	_tabs.clear_selection()


## Highlights the tab of `id`; any other id (home, settings) clears the row.
func select(id: String) -> void:
	if _tabs.button(StringName(id)):
		_tabs.select(StringName(id))
	else:
		_tabs.clear_selection()
	_wordmark.visible = id != "title"


## The ids of the tabs, left to right.
func tab_ids() -> Array[StringName]:
	return _tabs.ids()


## Level, title and XP bar; opens the Career page.
func _player_strip() -> Control:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("focus", KitTex.box(&"focus_ring"))
	b.tooltip_text = "Your level and career"
	b.custom_minimum_size = Vector2(250, 60)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func():
		UiSound.click()
		player_pressed.emit())
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", UiKit.GAP_S)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	row.add_child(UiKit.level_badge(60.0))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	_title = UiKit.label("", 24, UiKit.CREAM, true)
	_title.clip_text = true
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_title)
	_xp = UiKit.progress(0.0, 12.0, UiKit.AMBER)
	_xp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_xp)
	return b


func _ready() -> void:
	Cosmetics.equipped_changed.connect(func(_slot: StringName, _weapon: StringName): refresh())
	Progression.xp_changed.connect(func(_xp_now: int): refresh())
	resized.connect(queue_redraw)
	refresh()


## Re-reads the player's title and XP.
func refresh() -> void:
	var title := Cosmetics.equipped_or_default(&"title")
	_title.text = (title.display_name if title else "Rookie").to_upper()
	_xp.value = Progression.level_progress()


func _draw() -> void:
	var h := size.y
	draw_rect(Rect2(0, 0, size.x, h - RAIL), Color(UiKit.INK, 0.9))
	draw_rect(Rect2(0, h - RAIL, size.x, RAIL), UiKit.METAL)
	draw_rect(Rect2(0, h - RAIL, size.x, 3), UiKit.METAL.lightened(0.35))
	draw_rect(Rect2(0, h - 3, size.x, 3), UiKit.METAL.darkened(0.45))
	draw_rect(Rect2(0, h, size.x, 6), Color(0, 0, 0, 0.3))
	var rivet := KitTex.tex(&"rivet")
	if rivet == null:
		return
	var count := maxi(2, int(size.x / 240.0))
	var rect := Rect2(0, h - RAIL - 3, 16, 16)
	for i in count + 1:
		rect.position.x = clampf(size.x * i / count - 8.0, 6.0, size.x - 22.0)
		draw_texture_rect(rivet, rect, false)
