extends Control
## Main menu.
##   - Startup intro (once per session) that opens into the menu through a portal iris.
##   - Title: animated neon logo, staggered menu buttons (Play, every registered
##     page such as Arsenal / Career / Locker, Settings), the player's card and
##     operator when available, account level and a rotating tip.
##   - Play: world-select carousel over a live 3D backdrop that cross-fades to
##     each world, level details and best scores, loadout, and Deploy.
## Pages registered in data/ui/*.tres (UiExtension MENU_PAGE) plug in here.

const MENU_MUSIC := &"menu_theme"
const TIPS := [
	"Right mouse aims down sights: tighter spread and more zoom.",
	"Headshots multiply your score. Chain kills inside 3 seconds for a combo.",
	"Sprint, then press C to slide. Jump out of a slide to keep the speed.",
	"Between waves, the Loadout Station sells energy and snacks and swaps weapons.",
	"Zombies flank. Keep moving and use both lanes around the station.",
	"A flawless wave doubles the wave-clear bonus.",
]

var _pages := {}
var _current_page := ""
## Where Back (and Esc) leads from a page opened from somewhere other than the title.
var _back_to := {}
var _page_tweens: Array[Tween] = []
var _selected_level: LevelData
var _selected_weapon: StringName
var _world_index := 0
var _backdrop: MenuBackdrop
var _atmosphere: MenuAtmosphere
var _fade: ColorRect
var _logo: NeonLogo
var _title_buttons: Array[Control] = []
var _tip: Label
var _tip_index := 0
# Play page widgets.
var _cards: Array[WorldCard] = []
var _carousel: Control
var _level_name: Label
var _level_world: Label
var _level_blurb: Label
var _level_stats: HBoxContainer
var _level_tabs: HBoxContainer
var _lock_label: Label
var _start_button: Button
var _loadout_box: VBoxContainer
var _arsenal_button: Button


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().paused = false
	Game.capture_mouse(false)

	_backdrop = MenuBackdrop.new()
	add_child(_backdrop)
	_atmosphere = MenuAtmosphere.new()
	add_child(_atmosphere)
	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.0, 0.06)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.setup(_fade)

	_selected_weapon = StringName(String(Profile.data.get("last_weapon", "")))
	if GameData.weapon(_selected_weapon) == null:
		_selected_weapon = GameData.default_weapon_id()
	_world_index = clampi(int(Profile.section("menu").get("world", 0)), 0, maxi(0, GameData.worlds().size() - 1))

	_pages["play"] = _build_play()
	_pages["settings"] = _build_settings()
	for ext in GameData.ui_extensions(UiExtension.Kind.MENU_PAGE):
		if ext.script_ref == null:
			continue
		var page: Control = ext.script_ref.new()
		page.name = String(ext.id)
		if page.has_signal("back"):
			page.back.connect(_go_back)
		if page.has_signal("open_page"):
			page.open_page.connect(func(id: StringName): _show(String(id)))
		_pages[String(ext.id)] = page
	_pages["title"] = _build_title()
	for key in _pages:
		add_child(_pages[key])
		_pages[key].visible = false
	# Below the pages: backdrop cross-fades dim the 3D scene, not the UI.
	add_child(_fade)
	move_child(_fade, _atmosphere.get_index() + 1)

	_show_world_backdrop(true)
	Sfx.play_music(MENU_MUSIC, -9.0)

	var dev := Game.has_node("DevDriver")
	if not Game.intro_played and not dev and DisplayServer.get_name() != "headless":
		Game.intro_played = true
		_show("title", false)
		_pages["title"].visible = false
		get_viewport().gui_release_focus()
		var intro := IntroOverlay.new()
		add_child(intro)
		intro.finished.connect(func(): _animate_title_in())
	else:
		_show(Game.menu_page if _pages.has(Game.menu_page) else "title")
	Game.menu_page = ""

	if Profile.recovered_from_bad_save:
		Profile.recovered_from_bad_save = false
		_toast("Your save file could not be read, so a fresh profile was started. A copy of the old file was kept.")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _current_page != "title":
		if _current_page == "settings":
			Settings.save()
		_go_back()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	# The world carousel takes left/right before focus navigation does, so the
	# arrows and d-pad always browse worlds on the Play page.
	if _current_page != "play" or not _pages["play"].visible:
		return
	if event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		_step_world(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		_step_world(1)
		get_viewport().set_input_as_handled()


func _go_back() -> void:
	_show(_back_to.get(_current_page, "title"))


## Opens `page` so that Back returns to the page showing now.
func _open_from_here(page: String) -> void:
	_back_to[page] = _current_page
	_show(page)


## Switches page with a quick slide/fade. `animate` false = instant.
func _show(page: String, animate := true) -> void:
	if not _pages.has(page):
		return
	var old: Control = _pages.get(_current_page)
	if page == "title":
		_back_to.clear()
	_current_page = page
	for tw in _page_tweens:
		if tw and tw.is_valid():
			tw.kill()
	_page_tweens.clear()
	for key in _pages:
		_pages[key].position.x = 0.0
		_pages[key].modulate.a = 1.0
		if key != page and _pages[key] != old:
			_pages[key].visible = false
	var new_page: Control = _pages[page]
	new_page.visible = true
	if new_page.has_method("refresh"):
		new_page.refresh()
	if page == "play":
		_refresh_play()
	if page == "title":
		_refresh_title()
	if animate and old and old != new_page:
		var dir := -1.0 if page == "title" else 1.0
		old.visible = true
		var tw := create_tween().set_parallel(true)
		_page_tweens.append(tw)
		tw.tween_property(old, "modulate:a", 0.0, 0.18)
		tw.tween_property(old, "position:x", -60.0 * dir, 0.18)
		tw.chain().tween_callback(func():
			old.visible = false
			old.position.x = 0.0
			old.modulate.a = 1.0)
		new_page.modulate.a = 0.0
		new_page.position.x = 60.0 * dir
		var tw2 := create_tween().set_parallel(true)
		_page_tweens.append(tw2)
		tw2.tween_property(new_page, "modulate:a", 1.0, 0.25).set_delay(0.08)
		tw2.tween_property(new_page, "position:x", 0.0, 0.3).set_delay(0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		Sfx.play(&"ui_whoosh", -14.0, 1.3)
	elif old and old != new_page:
		old.visible = false
	var focus: Control = null
	if new_page.has_method("first_focus"):
		focus = new_page.first_focus()
	if focus == null:
		focus = new_page.find_child("FirstFocus", true, false) as Control
	if focus and focus.is_inside_tree():
		focus.grab_focus()


# --- title -------------------------------------------------------------------

func _build_title() -> Control:
	var page := Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_logo = NeonLogo.new()
	_logo.size_px = 132
	_logo.position = Vector2(110, 70)
	page.add_child(_logo)

	var col := VBoxContainer.new()
	col.position = Vector2(118, 470)
	col.add_theme_constant_override("separation", 12)
	page.add_child(col)
	var items := [["PLAY", "play", UiKit.PINK]]
	for ext in GameData.ui_extensions(UiExtension.Kind.MENU_PAGE):
		if ext.show_on_title and _pages.has(String(ext.id)):
			items.append([ext.title.to_upper(), String(ext.id), ext.accent])
	items.append(["SETTINGS", "settings", UiKit.TEAL])
	_title_buttons.clear()
	for i in items.size():
		var item: Array = items[i]
		var b := MenuButtonFx.make(item[0], item[2], 64 if i == 0 else 42, Vector2(520 if i == 0 else 430, 96 if i == 0 else 70))
		b.pressed.connect(_show.bind(item[1]))
		if i == 0:
			b.name = "FirstFocus"
		col.add_child(b)
		_title_buttons.append(b)
	var quit := MenuButtonFx.make("QUIT", UiKit.PURPLE, 30, Vector2(220, 52))
	quit.pressed.connect(func(): get_tree().quit())
	col.add_child(UiKit.spacer(6))
	col.add_child(quit)
	_title_buttons.append(quit)

	# Right side: player card + operator (when the cosmetics system provides
	# them), otherwise an account-level badge.
	var right := VBoxContainer.new()
	right.name = "PlayerArea"
	right.add_theme_constant_override("separation", 10)
	right.alignment = BoxContainer.ALIGNMENT_END
	page.add_child(right)
	right.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	right.offset_left = -640
	right.offset_right = -70
	right.offset_top = 60
	right.offset_bottom = -110
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Bottom ticker: tips.
	var ticker := PanelContainer.new()
	ticker.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.INK, 0.55), Color.TRANSPARENT, 14, 0, 12))
	page.add_child(ticker)
	ticker.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	ticker.offset_left = 118
	ticker.offset_right = -70
	ticker.offset_top = -86
	ticker.offset_bottom = -34
	_tip = UiKit.label("", 24, UiKit.CREAM)
	ticker.add_child(_tip)
	_tip_index = randi() % TIPS.size()
	_rotate_tip()
	var timer := Timer.new()
	timer.wait_time = 7.0
	timer.autostart = true
	timer.timeout.connect(_rotate_tip)
	page.add_child(timer)
	return page


func _refresh_title() -> void:
	var area := _pages["title"].get_node("PlayerArea") as VBoxContainer
	for c in area.get_children():
		c.queue_free()
	var card_script := "res://scripts/cosmetics/player_card.gd"
	var op_script := "res://scripts/cosmetics/operator_preview.gd"
	if ResourceLoader.exists(op_script):
		var op: Control = load(op_script).new()
		op.custom_minimum_size = Vector2(520, 560)
		op.size_flags_vertical = Control.SIZE_EXPAND_FILL
		op.mouse_filter = Control.MOUSE_FILTER_IGNORE
		area.add_child(op)
	if ResourceLoader.exists(card_script):
		var card: Control = load(card_script).build(true)
		card.size_flags_horizontal = Control.SIZE_SHRINK_END
		area.add_child(card)
	else:
		area.add_child(_level_badge())


## Account level badge (used when no player card is available).
func _level_badge() -> Control:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.NAVY, 0.88), UiKit.CYAN, 20, 3, 18))
	box.size_flags_horizontal = Control.SIZE_SHRINK_END
	box.custom_minimum_size = Vector2(420, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	box.add_child(v)
	var row := HBoxContainer.new()
	v.add_child(row)
	var t := UiKit.label("PLAYER LEVEL", 24, UiKit.CYAN, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	row.add_child(UiKit.arcade_label(str(Progression.level()), 52, Color.WHITE))
	v.add_child(UiKit.progress(Progression.level_progress(), 16.0))
	var best := 0
	for w in GameData.worlds():
		for l in w.levels:
			best = maxi(best, Profile.best_score(l.id))
	v.add_child(UiKit.label("Best score  %s" % ScorePanel._fmt(best), 22, UiKit.CREAM))
	return box


func _rotate_tip() -> void:
	if _tip == null:
		return
	_tip_index = (_tip_index + 1) % TIPS.size()
	_tip.text = "TIP  ·  " + TIPS[_tip_index]
	_tip.modulate.a = 0.0
	_tip.create_tween().tween_property(_tip, "modulate:a", 1.0, 0.4)


## After the intro: the title page fades in, logo letters drop, buttons slide in.
func _animate_title_in() -> void:
	var page: Control = _pages["title"]
	page.visible = true
	page.modulate.a = 1.0
	_logo.appear(0.0, 0.04)
	for i in _title_buttons.size():
		var b := _title_buttons[i]
		b.modulate.a = 0.0
		var home := b.position
		var tw := b.create_tween()
		tw.tween_interval(0.25 + i * 0.06)
		tw.tween_callback(func(): b.position.x = -80.0)
		tw.set_parallel(true)
		tw.tween_property(b, "modulate:a", 1.0, 0.2)
		tw.tween_property(b, "position:x", home.x, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var first := page.find_child("FirstFocus", true, false) as Control
	if first:
		first.grab_focus()


# --- play: world select ------------------------------------------------------

func _build_play() -> Control:
	var page := Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var head := HBoxContainer.new()
	page.add_child(head)
	head.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	head.offset_left = 110
	head.offset_right = -70
	head.offset_top = 46
	var title := UiKit.arcade_label("SELECT WORLD", 76, Color.WHITE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var back := MenuButtonFx.make("BACK", UiKit.TEAL, 30, Vector2(170, 56))
	back.pressed.connect(_show.bind("title"))
	head.add_child(back)

	# World cards (carousel) along the bottom-left.
	_carousel = Control.new()
	_carousel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(_carousel)
	_carousel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_carousel.offset_top = -330
	_carousel.offset_bottom = -40
	_cards.clear()
	for i in GameData.worlds().size():
		var card := WorldCard.new()
		card.world = GameData.worlds()[i]
		card.index = i
		card.pressed.connect(_select_world.bind(i))
		_carousel.add_child(card)
		_cards.append(card)
	var left := MenuButtonFx.make("<", UiKit.PURPLE, 44, Vector2(70, 120))
	left.pressed.connect(_step_world.bind(-1))
	page.add_child(left)
	left.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	left.offset_left = 20
	left.offset_top = -250
	left.offset_right = 90
	left.offset_bottom = -130
	var right := MenuButtonFx.make(">", UiKit.PURPLE, 44, Vector2(70, 120))
	right.pressed.connect(_step_world.bind(1))
	page.add_child(right)
	right.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	right.offset_left = -90
	right.offset_top = -250
	right.offset_right = -20
	right.offset_bottom = -130

	# Level details panel (top-left, under the heading).
	var info := PanelContainer.new()
	info.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.NAVY, 0.82), UiKit.PINK, 22, 3, 24))
	page.add_child(info)
	info.position = Vector2(110, 150)
	info.custom_minimum_size = Vector2(760, 0)
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 6)
	info.add_child(iv)
	_level_world = UiKit.label("", 26, UiKit.CYAN, true)
	iv.add_child(_level_world)
	_level_name = UiKit.arcade_label("", 72, Color.WHITE)
	iv.add_child(_level_name)
	_level_blurb = UiKit.label("", 25, UiKit.CREAM)
	_level_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_level_blurb.custom_minimum_size = Vector2(700, 0)
	iv.add_child(_level_blurb)
	_level_tabs = HBoxContainer.new()
	_level_tabs.add_theme_constant_override("separation", 10)
	iv.add_child(_level_tabs)
	_level_stats = HBoxContainer.new()
	_level_stats.add_theme_constant_override("separation", 12)
	iv.add_child(_level_stats)
	_lock_label = UiKit.arcade_label("", 30, UiKit.AMBER)
	iv.add_child(_lock_label)

	# Loadout + deploy (top-right).
	var side := PanelContainer.new()
	side.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.NAVY, 0.82), UiKit.CYAN, 22, 3, 22))
	page.add_child(side)
	side.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	side.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	side.offset_left = -560
	side.offset_right = -70
	side.offset_top = 150
	side.custom_minimum_size = Vector2(490, 0)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 10)
	side.add_child(sv)
	sv.add_child(UiKit.label("LOADOUT", 28, UiKit.CYAN, true))
	_loadout_box = VBoxContainer.new()
	_loadout_box.add_theme_constant_override("separation", 6)
	sv.add_child(_loadout_box)
	if GameData.ui_extensions(UiExtension.Kind.MENU_PAGE).any(func(e): return e.id == &"arsenal"):
		_arsenal_button = MenuButtonFx.make("OPEN ARSENAL", UiKit.TEAL, 26, Vector2(0, 52))
		_arsenal_button.pressed.connect(_open_from_here.bind("arsenal"))
		sv.add_child(_arsenal_button)
	sv.add_child(UiKit.spacer(6))
	_start_button = MenuButtonFx.make("DEPLOY", UiKit.PINK, 60, Vector2(0, 100))
	_start_button.name = "FirstFocus"
	_start_button.pressed.connect(_start)
	sv.add_child(_start_button)
	return page


func _select_world(i: int) -> void:
	if i < 0 or i >= GameData.worlds().size():
		return
	if i != _world_index:
		Sfx.play(&"ui_click", -8.0, 1.15)
	_world_index = i
	Profile.section("menu")["world"] = i
	var world := GameData.worlds()[i]
	_selected_level = null
	for l in world.levels:
		if GameData.is_level_unlocked(l):
			_selected_level = l
			break
	if _selected_level == null and not world.levels.is_empty():
		_selected_level = world.levels[0]
	_show_world_backdrop(false)
	_refresh_play()


func _step_world(step: int) -> void:
	var n := GameData.worlds().size()
	if n > 0:
		_select_world(posmod(_world_index + step, n))


func _show_world_backdrop(instant: bool) -> void:
	var worlds := GameData.worlds()
	if worlds.is_empty():
		return
	var world := worlds[clampi(_world_index, 0, worlds.size() - 1)]
	if world.levels.is_empty():
		return
	var level := _selected_level if _selected_level and _selected_level.world == world else world.levels[0]
	_backdrop.show_level(level, instant)
	_atmosphere.accent = world.accent_color


func _select_level(level: LevelData) -> void:
	_selected_level = level
	_show_world_backdrop(false)
	_refresh_play()


func _select_weapon(weapon_id: StringName) -> void:
	_selected_weapon = weapon_id
	_refresh_play()


func _refresh_play() -> void:
	var worlds := GameData.worlds()
	if worlds.is_empty():
		return
	_world_index = clampi(_world_index, 0, worlds.size() - 1)
	var world := worlds[_world_index]
	if _selected_level == null or _selected_level.world != world:
		_selected_level = null
		for l in world.levels:
			if GameData.is_level_unlocked(l):
				_selected_level = l
				break
		if _selected_level == null and not world.levels.is_empty():
			_selected_level = world.levels[0]
	_layout_cards()

	# Level details.
	var level := _selected_level
	_level_world.text = "WORLD %d  ·  %s" % [_world_index + 1, world.display_name.to_upper()]
	_level_world.add_theme_color_override("font_color", world.secondary_color)
	_level_name.text = level.display_name.to_upper() if level else "COMING SOON"
	_level_blurb.text = (level.blurb if level and level.blurb != "" else world.blurb)
	for c in _level_tabs.get_children():
		c.queue_free()
	if world.levels.size() > 1:
		for l in world.levels:
			var tab := MenuButtonFx.make(l.display_name, world.accent_color if l == level else UiKit.PURPLE, 24, Vector2(0, 46))
			tab.pressed.connect(_select_level.bind(l))
			_level_tabs.add_child(tab)
	for c in _level_stats.get_children():
		c.queue_free()
	var unlocked := level != null and GameData.is_level_unlocked(level)
	if level:
		var waves := level.wave_set.waves.size() if level.wave_set else 0
		_level_stats.add_child(_stat_chip("WAVES", str(waves), world.accent_color))
		_level_stats.add_child(_stat_chip("BEST SCORE", ScorePanel._fmt(Profile.best_score(level.id)), world.accent_color))
		_level_stats.add_child(_stat_chip("BEST WAVE", str(Profile.best_wave(level.id)), world.accent_color))
		_level_stats.add_child(_stat_chip("STATUS", "CLEARED" if Profile.is_level_completed(level.id) else ("OPEN" if unlocked else "LOCKED"), world.secondary_color))
	_lock_label.text = "" if unlocked or level == null else "LOCKED  ·  " + GameData.lock_reason(level)
	_start_button.disabled = not unlocked
	_start_button.text = "DEPLOY" if unlocked else "LOCKED"

	# Loadout summary (chosen in the Arsenal, swapped at the Loadout Station).
	for c in _loadout_box.get_children():
		c.queue_free()
	for slot in [["PRIMARY  ·  1", Loadout.primary()], ["SECONDARY  ·  2", Loadout.secondary()]]:
		_loadout_box.add_child(_weapon_row(slot[0], GameData.weapon(slot[1])))


func _weapon_row(caption: String, w: WeaponData) -> Control:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.INK, 0.7), Color.TRANSPARENT, 14, 0, 12))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -4)
	box.add_child(v)
	v.add_child(UiKit.label(caption, 18, UiKit.CYAN, true))
	v.add_child(UiKit.label(w.display_name.to_upper() if w else "—", 30, Color.WHITE, true))
	if w:
		var rank := Mastery.rank(w.id)
		v.add_child(UiKit.label("%s  ·  Mastery rank %d" % [w.category if w.category != "" else "Weapon", rank], 20, UiKit.CREAM))
	return box


func _stat_chip(caption: String, value: String, accent: Color) -> Control:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.INK, 0.72), Color(accent, 0.6), 14, 2, 10))
	box.custom_minimum_size = Vector2(160, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -6)
	box.add_child(v)
	var c := UiKit.label(caption, 17, accent, true)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(c)
	var val := UiKit.label(value, 34, Color.WHITE, true)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(val)
	return box


## Lays the world cards out as a carousel centred on the selected world.
func _layout_cards() -> void:
	var width := _carousel.size.x if _carousel.size.x > 0 else 1920.0
	var card_w := 520.0
	var gap := 36.0
	for card: WorldCard in _cards:
		var offset: int = card.index - _world_index
		var target_x := width * 0.5 - card_w * 0.5 + offset * (card_w + gap)
		var selected := offset == 0
		card.selected = selected
		var tw := card.create_tween().set_parallel(true)
		tw.tween_property(card, "position", Vector2(target_x, 0 if selected else 26), 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "scale", Vector2.ONE * (1.0 if selected else 0.88), 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "modulate", Color(1, 1, 1, 1.0) if selected else Color(0.75, 0.75, 0.85, 0.85), 0.25)
		card.queue_redraw()


func _start() -> void:
	if _selected_level == null:
		return
	Profile.save_profile()
	Sfx.play(&"deploy", -2.0)
	# The saved Loadout, unless a dev run picked a weapon.
	var weapon := _selected_weapon if Game.has_node("DevDriver") else &""
	Game.start_level(_selected_level.id, weapon)


# --- settings ----------------------------------------------------------------

func _build_settings() -> Control:
	var page := Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	# The header (title, BACK at the top right) stays put above the scrolling list.
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var settings := SettingsPanel.new()
	settings.closed.connect(_show.bind("title"))
	column.add_child(settings.header)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(960, 780)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	scroll.add_child(settings)
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
