extends Control
## Main menu: the shell every menu page lives in.
##   - The live 3D world behind everything, cross-fading as the player browses
##     worlds (or a page's own backdrop, such as the Arsenal's booth).
##   - The top bar, always there: home, a tab per section (Play, then every
##     page registered in data/ui/*.tres as a UiExtension MENU_PAGE, by
##     `order`), the player's level and Sparks, settings and quit.
##   - The header row of the open page (BACK sign, marquee title, the page's
##     own header controls) and the page itself. See MenuPage for the contract.
##   - Navigation: BACK / Esc returns to where the page was opened from, Q / E
##     (PageUp / PageDown, the shoulder buttons) step through the sections.
## The startup intro (once per session) opens into the home screen.
## Only home is built when the menu opens; the other pages are built one per
## frame in the background once the startup screen holds (or the home screen
## is up), and any page opened before that is built on the spot.

const MENU_MUSIC := &"menu_theme"
## How a page sits in the shell.
enum Frame {
	## The whole area under the top bar, no header row (home).
	FULL,
	## Header row drawn by the shell, the page gets the content rectangle.
	SHELL,
	## A page from before the shell: draws its own header, scaled to fit.
	LEGACY,
}
## Height the pre-shell pages were laid out for.
const LEGACY_HEIGHT := 1080.0

## Page id -> its frame (the Control that is shown, hidden and animated).
var _pages := {}
## Page id -> the page itself.
var _nodes := {}
## Page id -> [page factory, marquee title, Frame] for pages not built yet.
var _later := {}
## Builds the pages not opened yet, a page per frame.
var _build: BuildQueue
var _prebuild_started := false
## Resources loaded ahead for pages (kept so they stay in the cache).
var _held: Array[Resource] = []
## Page id -> the page's own full-screen backdrop, for pages that have one.
var _own_backdrops := {}
var _current_page := ""
## Where Back (and Esc) leads from a page opened from somewhere other than home.
var _back_to := {}
var _page_tweens: Array[Tween] = []
var _backdrop: MenuBackdrop
var _atmosphere: MenuAtmosphere
var _fade: ColorRect
var _backdrop_host: Control
var _page_host: Control
var _top_bar: MenuTopBar
var _home: MenuHome
## The Play page (built on first use: see _play_page()).
var _play: MenuPlay
## The level DEPLOY starts (the dev driver sets it).
var _selected_level: LevelData:
	get:
		return _play_page().selected_level
	set(v):
		_play_page().selected_level = v


func _ready() -> void:
	UiKit.apply(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().paused = false
	Game.capture_mouse(false)
	_build_layers()
	_build_pages()
	_show_world_backdrop(MenuPlay.remembered_level(), true)
	Sfx.play_music(MENU_MUSIC, -9.0)

	var dev := Game.has_node("DevDriver")
	if not Game.intro_played and not dev and DisplayServer.get_name() != "headless":
		Game.intro_played = true
		_show("title", false)
		_pages["title"].visible = false
		_top_bar.modulate.a = 0.0
		get_viewport().gui_release_focus()
		var intro := IntroOverlay.new()
		add_child(intro)
		intro.finished.connect(_on_intro_finished)
		intro.holding.connect(_prebuild)
	else:
		_show(Game.menu_page if _has_page(Game.menu_page) else "title", false)
		# A moment for the home screen to come up before the rest is built.
		get_tree().create_timer(0.3).timeout.connect(_prebuild)
	Game.menu_page = ""

	if Profile.recovered_from_bad_save:
		Profile.recovered_from_bad_save = false
		UiKit.toast("Your save file could not be read, so a fresh profile was started. A copy of the old file was kept.", UiKit.AMBER, &"", 8.0)


## The 3D world, the atmosphere over it, the cross-fade veil, then the layers
## pages live in, with the top bar above them all.
func _build_layers() -> void:
	_backdrop = MenuBackdrop.new()
	add_child(_backdrop)
	_atmosphere = MenuAtmosphere.new()
	add_child(_atmosphere)
	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.0, 0.06)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)
	_backdrop.setup(_fade)
	_backdrop_host = _layer()
	_page_host = _layer()
	_top_bar = MenuTopBar.new()
	add_child(_top_bar)
	_top_bar.home_pressed.connect(_show.bind("title"))
	_top_bar.tab_pressed.connect(_show)
	_top_bar.player_pressed.connect(_show.bind("career"))
	_top_bar.settings_pressed.connect(_open_from_here.bind("settings"))
	_top_bar.quit_pressed.connect(_ask_quit)


func _layer() -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


func _build_pages() -> void:
	_build = BuildQueue.new()
	add_child(_build)
	_home = MenuHome.new()
	_home.play_requested.connect(_on_play_requested)
	_register("title", _home, "", Frame.FULL)
	_later["play"] = [_new_play, "SELECT WORLD", Frame.SHELL]
	_top_bar.add_tab("play", "PLAY")
	var extensions := GameData.ui_extensions(UiExtension.Kind.MENU_PAGE)
	extensions.sort_custom(func(a: UiExtension, b: UiExtension): return a.order < b.order)
	for ext in extensions:
		if ext.script_ref == null:
			continue
		var script: Script = ext.script_ref
		_later[String(ext.id)] = [func() -> Control: return script.new(), ext.title.to_upper(), null]
		if ext.show_on_title:
			_top_bar.add_tab(String(ext.id), ext.title)
	_later["settings"] = [func() -> Control: return MenuSettings.new(), "SETTINGS", Frame.SHELL]
	_home.known_pages.assign(["title"] + _later.keys())


func _new_play() -> MenuPlay:
	_play = MenuPlay.new()
	_play.world_changed.connect(_show_world_backdrop.bind(false))
	return _play


func _has_page(id: String) -> bool:
	return _pages.has(id) or _later.has(id)


## Builds page `id` now if it has not been built yet.
func _ensure(id: String) -> void:
	if not _later.has(id):
		return
	var entry: Array = _later[id]
	_later.erase(id)
	var page: Control = (entry[0] as Callable).call()
	var frame_kind = entry[2]
	if frame_kind == null:
		var shell_page := page is MenuPage and (page as MenuPage).uses_shell_header()
		frame_kind = Frame.SHELL if shell_page else Frame.LEGACY
	_register(id, page, entry[1], frame_kind)


func _play_page() -> MenuPlay:
	_ensure("play")
	return _play


## Queues every page not built yet, one per frame, each followed by its warm-up
## (cards made ahead, see MenuPage.prewarm()). Play waits for its key art.
func _prebuild() -> void:
	if _prebuild_started or not is_inside_tree():
		return
	_prebuild_started = true
	KeyArt.prefetch()
	for id in _later.keys():
		for path in _heavy(id):
			ResourceLoader.load_threaded_request(path)
		_build.add(_prebuild_page.bind(id))


## The resources page `id` loads when built (MenuPage.heavy_resources()).
func _heavy(id: String) -> PackedStringArray:
	var entry: Array = _later.get(id, [])
	if entry.is_empty():
		return PackedStringArray()
	var script := (entry[0] as Callable).get_object() as Script
	if script == null or not script.get_script_constant_map().has("HEAVY_RESOURCES"):
		return PackedStringArray()
	return PackedStringArray(script.get_script_constant_map()["HEAVY_RESOURCES"])


func _prebuild_page(id: String) -> void:
	var waiting := id == "play" and not KeyArt.prefetched()
	for path in _heavy(id):
		waiting = waiting or ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS
	if waiting:
		get_tree().create_timer(0.1).timeout.connect(func(): _build.add(_prebuild_page.bind(id)))
		return
	for path in _heavy(id):
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
			_held.append(ResourceLoader.load_threaded_get(path))
	_ensure(id)
	var page := _nodes.get(id) as MenuPage
	if page:
		page.prewarm(_build)


## Adds `page` to the shell under `id`, in the frame its kind needs.
func _register(id: String, page: Control, title: String, frame_kind: Frame) -> void:
	page.name = id
	if page.has_signal("back"):
		page.back.connect(_go_back)
	if page.has_signal("open_page"):
		page.open_page.connect(func(target: StringName): _open_from_here(String(target)))
	var frame := Control.new()
	frame.name = id + "_frame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.visible = false
	_page_host.add_child(frame)
	frame.add_child(page)
	_pages[id] = frame
	_nodes[id] = page
	match frame_kind:
		Frame.FULL:
			page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			page.offset_top = MenuPage.TOP_BAR
		Frame.SHELL:
			_frame_shell_page(frame, page as MenuPage, title)
		Frame.LEGACY:
			frame.resized.connect(_fit_legacy.bind(frame, page))
			_fit_legacy.call_deferred(frame, page)


## Header row (BACK, marquee, the page's extras) and the content rectangle.
func _frame_shell_page(frame: Control, page: MenuPage, title: String) -> void:
	var top := MenuPage.TOP_BAR + UiKit.GAP_S
	var head := HBoxContainer.new()
	head.name = "Header"
	head.add_theme_constant_override("separation", UiKit.GAP_L)
	frame.add_child(head)
	head.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	head.offset_left = UiKit.PAGE_MARGIN * 0.5
	head.offset_right = -UiKit.PAGE_MARGIN
	head.offset_top = top
	head.offset_bottom = top + MenuPage.HEADER
	var back := UiKit.back_button()
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_go_back)
	head.add_child(back)
	var sign := UiKit.marquee(title, 50)
	sign.name = "Marquee"
	sign.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(sign)
	var extra := page.header_extra()
	if extra:
		extra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		extra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(extra)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.offset_left = UiKit.PAGE_MARGIN
	page.offset_right = -UiKit.PAGE_MARGIN
	page.offset_top = top + MenuPage.HEADER + UiKit.GAP_S
	page.offset_bottom = -UiKit.GAP_L
	var own := page.backdrop()
	if own:
		own.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		own.visible = false
		_backdrop_host.add_child(own)
		_own_backdrops[page.name] = own


## A pre-shell page believes it owns a 1080-high canvas: give it one, scaled
## to the area under the top bar.
func _fit_legacy(frame: Control, page: Control) -> void:
	var room := frame.size.y - MenuPage.TOP_BAR
	var k := minf(1.0, room / LEGACY_HEIGHT)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.scale = Vector2(k, k)
	page.position = Vector2(0.0, MenuPage.TOP_BAR)
	page.size = Vector2(frame.size.x, room) / k


## The page registered as `id` (null if there is none), built if need be.
func page(id: String) -> Control:
	_ensure(id)
	return _nodes.get(id)


# --- navigation ------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if KitDialog.open_count > 0:
		return
	if event.is_action_pressed("ui_cancel") and _current_page != "title":
		_go_back()
		get_viewport().set_input_as_handled()
		return
	var step := _section_step(event)
	if step != 0:
		_step_section(step)
		get_viewport().set_input_as_handled()
	elif get_viewport().gui_get_focus_owner() == null and _is_navigation(event):
		# Nothing has focus (its control went away): hand it back to the page.
		_focus_page(_nodes[_current_page])
		get_viewport().set_input_as_handled()


func _is_navigation(event: InputEvent) -> bool:
	for action in [&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_accept", &"ui_focus_next", &"ui_focus_prev"]:
		if event.is_action_pressed(action):
			return true
	return false


## -1 / 1 for the keys and buttons that step through the top bar's sections.
func _section_step(event: InputEvent) -> int:
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).physical_keycode:
			KEY_Q, KEY_PAGEUP:
				return -1
			KEY_E, KEY_PAGEDOWN:
				return 1
	elif event is InputEventJoypadButton and event.pressed:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_LEFT_SHOULDER:
				return -1
			JOY_BUTTON_RIGHT_SHOULDER:
				return 1
	return 0


## Moves to the next or previous section: home, then the tabs in order.
func _step_section(step: int) -> void:
	var order: Array[String] = ["title"]
	for id in _top_bar.tab_ids():
		order.append(String(id))
	var at := order.find(_current_page)
	if at < 0:
		at = 0
	_show(order[posmod(at + step, order.size())])


func _go_back() -> void:
	var node: Control = _nodes.get(_current_page)
	if node is MenuPage and (node as MenuPage).handle_back():
		return
	_show(_back_to.get(_current_page, "title"))


## Opens `page` so that Back returns to the page showing now.
func _open_from_here(page_id: String) -> void:
	if page_id != _current_page:
		_back_to[page_id] = _current_page
	_show(page_id)


## Switches page with a quick slide and fade. `animate` false = instant.
func _show(page_id: String, animate := true) -> void:
	_ensure(page_id)
	if not _pages.has(page_id) or (page_id == _current_page and animate):
		return
	var old: Control = _pages.get(_current_page)
	var direction := _direction(_current_page, page_id)
	if page_id == "title":
		_back_to.clear()
	_current_page = page_id
	for tw in _page_tweens:
		if tw and tw.is_valid():
			tw.kill()
	_page_tweens.clear()
	for key in _pages:
		var frame: Control = _pages[key]
		frame.position.x = 0.0
		frame.modulate.a = 1.0
		frame.visible = key == page_id or (animate and frame == old)
	var new_frame: Control = _pages[page_id]
	var node: Control = _nodes[page_id]
	if node.has_method("refresh"):
		node.refresh()
	_top_bar.select(page_id)
	_show_own_backdrop(page_id, animate)
	if animate and old and old != new_frame:
		_page_tweens.append(UiFx.page_out(old, direction))
		_page_tweens.append(UiFx.page_in(new_frame, direction))
		UiSound.page()
		var sign := new_frame.get_node_or_null("Header/Marquee") as MarqueeSign
		if sign:
			sign.flash()
	_focus_page(node)


## 1 when `to` sits to the right of `from` in the top bar (pages slide that way).
func _direction(from: String, to: String) -> float:
	var order: Array[String] = ["title"]
	for id in _top_bar.tab_ids():
		order.append(String(id))
	var a := order.find(from)
	var b := order.find(to)
	if b < 0:
		return 1.0
	return -1.0 if b < a or (a < 0 and to == "title") else 1.0


func _focus_page(node: Control) -> void:
	var focus: Control = null
	if node.has_method("first_focus"):
		focus = node.first_focus()
	if focus == null:
		focus = node.find_child("FirstFocus", true, false) as Control
	if focus and focus.is_inside_tree():
		focus.grab_focus()


## A page's own backdrop replaces the live world while that page is open.
func _show_own_backdrop(page_id: String, animate: bool) -> void:
	var own: Control = _own_backdrops.get(page_id)
	for key in _own_backdrops:
		var layer: Control = _own_backdrops[key]
		if layer != own and layer.visible:
			var out := layer.create_tween()
			out.tween_property(layer, "modulate:a", 0.0, UiFx.PAGE if animate else 0.0)
			out.tween_callback(func(): layer.visible = false)
	_backdrop.visible = true
	if own == null:
		return
	own.visible = true
	own.modulate.a = 0.0 if animate else 1.0
	var tw := own.create_tween()
	tw.tween_property(own, "modulate:a", 1.0, UiFx.PAGE if animate else 0.0)
	# Once it covers the screen there is no need to draw the world behind it.
	tw.tween_callback(func(): _backdrop.visible = _own_backdrops.get(_current_page) != own)


func _ask_quit() -> void:
	UiKit.confirm(self, "QUIT THE GAME?", "Your progress is saved.", "QUIT", func(): get_tree().quit())


# --- pages ---------------------------------------------------------------------------

func _on_intro_finished() -> void:
	_pages["title"].visible = true
	_top_bar.create_tween().tween_property(_top_bar, "modulate:a", 1.0, 0.4)
	_home.animate_in()
	_focus_page(_home)
	if Onboarding.wants_first_run():
		Onboarding.begin_first_run(self)


func _on_play_requested(world_index: int) -> void:
	_play_page().select_world(world_index)
	_show("play")


func _show_world_backdrop(level: LevelData, instant: bool) -> void:
	if level == null:
		return
	_backdrop.show_level(level, instant)
	if level.world:
		_atmosphere.accent = level.world.accent_color


## Dev driver entry points (scripts/dev/dev_driver.gd).
func _select_weapon(weapon_id: StringName) -> void:
	_play_page().selected_weapon = weapon_id


func _start() -> void:
	_play_page().start()
