class_name MenuPlay
extends MenuPage
## The Play page: pick a world from the carousel of key-art cards (locked
## ones show what opens them), read the level's details, best results,
## progress stars and the zombies that wait there, choose the difficulty,
## check the loadout and DEPLOY. Left/right (or A/D, held to run through
## them), the mouse wheel, a drag or a pip browse the worlds; the carousel
## glides between them with depth (cards shrink, fan out and fade with
## distance, their art slides behind the frame), and the picked world's
## accent pools under it. The carousel keeps to its own band under the
## boards: the pips on top, then the card tray (a framed box that clips the
## cards) between the two arrows; every card fits the tray's height whole.
##
## Two modes, picked with the large STORY / ENDLESS tabs in the header (or
## Tab / the gamepad's Y): STORY browses the worlds; ENDLESS (an EndlessCard
## per endless level, open from player level 1) shows the city's board: the
## best wave and score, the districts opened and the reward track read from
## the catalog (EndlessRewards), and DEPLOY reads START. The ENDLESS tab
## wears a NEW badge until the player has started an Endless run. The mode,
## the world and the endless level browsed last are kept in the profile's
## "menu" section ("mode", "world", "endless").

## The world in the carousel changed: the shell cross-fades the backdrop.
signal world_changed(level: LevelData)

const ENEMY_CHIPS := 7
## The enemy chips keep to this many rows (the rest are counted on "+N MORE"),
## so the details board leaves the carousel its band.
const ENEMY_ROWS := 2
## The level's name keeps to one line: its font shrinks to fit, down to this.
const NAME_FONT := 68
const NAME_FONT_MIN := 44
## Lines of the level's blurb shown (the rest is cut and in its tooltip).
const BLURB_LINES := 2
## Size of the level's key art on the details board.
const ART_SIZE := Vector2(448, 252)
## The row of position pips (clickable) along the top of the carousel band.
const PIP_ROW := 30.0
const PIP_STEP := 36.0
## Cards further than this (in cards) from the selected one are hidden.
const CARDS_AROUND := 2.6
## The selected card's scale in the tray, and each further card's relative
## to it (by distance 0, 1, 2, 3).
const CARD_SCALE := 0.74
const DEPTH_SCALE: Array[float] = [1.0, 0.8, 0.64, 0.52]
## Room inside the tray above and below the selected card.
const TRAY_PAD := 9.0
## The arrow buttons beside the tray.
const ARROW_SIZE := Vector2(60, 120)
## Seconds the carousel glides to a newly picked world (a little longer for a long jump).
const GLIDE := 0.42
## While an arrow is held, the worlds go by at most this often (seconds).
const HOLD_STEP := 0.09
## Gap between neighbouring cards in the tray (canvas px).
const CARD_GAP := 24.0
const STORY := &"story"
## The Endless board's short rules: [what, the gist].
const HOW_IT_PLAYS := [["NO LAST WAVE", "EVERY 5TH A HORDE"], ["THE WRECKER", "EVERY 10TH WAVE"],
	["UPGRADE BENCH", "MK I-III FOR THE RUN"], ["POWER-UPS", "FROM FALLEN ZOMBIES"]]
const ENDLESS := &"endless"

var selected_level: LevelData
## Starter weapon for dev runs (the saved Loadout is used otherwise).
var selected_weapon: StringName
## The story world browsed (its carousel slot in STORY).
var world_index := 0
## STORY or ENDLESS.
var mode := STORY
## The endless level browsed (its carousel slot in ENDLESS).
var endless_index := 0
## The soft disc under the selected card (shared by every Play page).
static var _glow_tex: GradientTexture2D

## Every card: the worlds', then the endless levels' (each `index` is its
## slot in its own mode's row).
var _cards: Array[WorldCard] = []
## The carousel band (input, pips, arrows) and its tray, which clips the cards.
var _carousel: Control
var _tray: Control
var _tray_box := StyleBoxFlat.new()
var _pips: Control
var _pip_box := StyleBoxFlat.new()
## The carousel's position in worlds: fractional while it glides or is dragged.
var _scroll := 0.0
var _glide: Tween
var _glow_color := Color.TRANSPARENT
var _glow_tween: Tween
## Mouse drag on the carousel: where it started, the position then, and
## whether it moved far enough to be a drag rather than a click.
var _dragging := false
var _drag_x := 0.0
var _drag_scroll := 0.0
var _drag_moved := false
var _last_step_ms := 0
var _best_value: Label
var _star_row: HBoxContainer
var _lock_text: Label
var _world_caption: Label
var _level_name: Label
var _blurb: Label
var _level_tabs: HBoxContainer
var _stats: HBoxContainer
var _enemies: HFlowContainer
## The "+N MORE" chip among the enemy chips (after the kinds, before the
## bosses) and how many kinds the level's waves have.
var _more_chip: KitChip
var _enemy_kinds := 0
var _lock: Control
var _art: TextureRect
## In ENDLESS, the endless level's card takes the key art's place on the
## board (its emblem, chasing bulbs and best wave).
var _hero: EndlessCard
var _head: HBoxContainer
var _plates: Array[SlotPlate] = []
var _difficulty: KitTabs
var _difficulty_note: Label
var _deploy: SignButton
var _who: Control
var _endless_box: VBoxContainer
## The header's mode tabs and the key prompts beside them.
var _mode_tiles: Array[ModeTile] = []
var _browse_prompt: Control
var _deploy_prompt: HBoxContainer
var _arrows: Array[Control] = []


func _init() -> void:
	selected_weapon = StringName(String(Profile.data.get("last_weapon", "")))
	if GameData.weapon(selected_weapon) == null:
		selected_weapon = GameData.default_weapon_id()
	mode = saved_mode()
	world_index = saved_world()
	endless_index = clampi(int(Profile.section("menu").get("endless", 0)), 0, maxi(0, GameData.endless_levels().size() - 1))


## The level the Play page opens on: the endless level or the world browsed
## last (its first unlocked level). The shell shows it behind the menu
## before the page exists.
static func remembered_level() -> LevelData:
	var worlds := GameData.worlds()
	if saved_mode() == ENDLESS:
		var levels := GameData.endless_levels()
		return levels[clampi(int(Profile.section("menu").get("endless", 0)), 0, levels.size() - 1)]
	if worlds.is_empty():
		return null
	var world := worlds[saved_world()]
	for l in world.levels:
		if GameData.is_level_unlocked(l):
			return l
	return world.levels[0] if not world.levels.is_empty() else null


## The mode browsed last (a save from before the mode tabs kept Endless as
## the carousel slot after the last world).
static func saved_mode() -> StringName:
	if GameData.endless_levels().is_empty():
		return STORY
	var menu := Profile.section("menu")
	if menu.has("mode"):
		return ENDLESS if String(menu["mode"]) == String(ENDLESS) else STORY
	return ENDLESS if int(menu.get("world", 0)) >= GameData.worlds().size() else STORY


## The story world browsed last.
static func saved_world() -> int:
	var slot := int(Profile.section("menu").get("world", 0))
	return clampi(slot, 0, maxi(0, GameData.worlds().size() - 1)) if slot < GameData.worlds().size() else 0


## True until the player has started an Endless run (the ENDLESS tab's NEW badge).
static func endless_is_new() -> bool:
	return not bool(Profile.section("menu").get("endless_started", false)) and EndlessRecords.runs() == 0 and EndlessRecords.best_wave() == 0


## The selected slot of the current mode's row, and how many it has.
func _slot() -> int:
	return endless_index if mode == ENDLESS else world_index


func _slot_count() -> int:
	return (GameData.endless_levels() if mode == ENDLESS else GameData.worlds()).size()


func _in_row(card: WorldCard) -> bool:
	return (card is EndlessCard) == (mode == ENDLESS)


func uses_shell_header() -> bool:
	return true


## The two mode tabs, then the key prompts.
func header_extra() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiKit.GAP_M)
	if not GameData.endless_levels().is_empty():
		var group := ButtonGroup.new()
		_mode_tiles.append(ModeTile.make(STORY, "STORY", ModeTile.STORY_ACCENT, group))
		_mode_tiles.append(ModeTile.make(ENDLESS, "ENDLESS", EndlessCard.EMBER, group))
		for tile in _mode_tiles:
			tile.name = "Mode" + String(tile.mode).capitalize()
			tile.pressed.connect(select_mode.bind(tile.mode))
			row.add_child(tile)
		UiKit.tooltip(_mode_tiles[0], "The worlds, one level after another  (Tab)")
		UiKit.tooltip(_mode_tiles[1], "Survive waves without end in Ashfall City  (Tab)")
	row.add_child(UiKit.filler())
	var prompts := VBoxContainer.new()
	prompts.alignment = BoxContainer.ALIGNMENT_CENTER
	prompts.add_theme_constant_override("separation", UiKit.GAP_XS)
	row.add_child(prompts)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", UiKit.GAP_M)
	prompts.add_child(top)
	if not _mode_tiles.is_empty():
		top.add_child(UiKit.key_prompt("TAB", "Mode"))
	_deploy_prompt = UiKit.key_prompt("ENTER", "Deploy")
	top.add_child(_deploy_prompt)
	_browse_prompt = HBoxContainer.new()
	_browse_prompt.add_theme_constant_override("separation", UiKit.GAP_XS)
	_browse_prompt.add_child(UiKit.key_glyph("A"))
	_browse_prompt.add_child(UiKit.key_prompt("D", "Browse worlds"))
	prompts.add_child(_browse_prompt)
	_refresh_mode_tiles()
	return row


func _ready() -> void:
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", UiKit.GAP_M)
	add_child(col)
	var top := HBoxContainer.new()
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top.add_theme_constant_override("separation", UiKit.GAP_L)
	col.add_child(top)
	top.add_child(_build_info())
	top.add_child(_build_side())
	col.add_child(_build_carousel())
	resized.connect(_layout_cards.bind(false))
	refresh()


func refresh() -> void:
	if _carousel == null:
		return
	for card in _cards:
		card.refresh()
	_refresh_mode_tiles()
	_difficulty.select(Difficulty.current())
	_difficulty_note.text = Difficulty.description(Difficulty.current())
	_refresh_details()
	_layout_cards(false)


func first_focus() -> Control:
	return _deploy


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or KitDialog.open_count > 0:
		return
	if _is_mode_toggle(event):
		get_viewport().set_input_as_handled()
		select_mode(STORY if mode == ENDLESS else ENDLESS)
		return
	var step := 0
	if event.is_action_pressed("ui_left", true) or event.is_action_pressed("move_left", true):
		step = -1
	elif event.is_action_pressed("ui_right", true) or event.is_action_pressed("move_right", true):
		step = 1
	if step == 0:
		return
	# Inside the mode tabs and the difficulty row the arrows move between their options.
	var focus := get_viewport().gui_get_focus_owner()
	if focus is ModeTile and not (event is InputEventKey and (event as InputEventKey).physical_keycode in [KEY_A, KEY_D]):
		return
	if focus and _difficulty.is_ancestor_of(focus) and not (event is InputEventKey and (event as InputEventKey).physical_keycode in [KEY_A, KEY_D]):
		return
	get_viewport().set_input_as_handled()
	if event.is_echo():
		# Held: run through the worlds at a steady pace, stopping at either end.
		if Time.get_ticks_msec() - _last_step_ms < HOLD_STEP * 1000.0:
			return
		_select_slot(clampi(_slot() + step, 0, _slot_count() - 1))
	else:
		step_world(step)
	_last_step_ms = Time.get_ticks_msec()


## Tab or the gamepad's Y switches the mode (while there are two).
func _is_mode_toggle(event: InputEvent) -> bool:
	if _mode_tiles.is_empty() or event.is_echo():
		return false
	if event is InputEventKey and event.pressed:
		return (event as InputEventKey).physical_keycode == KEY_TAB
	return event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_Y


# --- layout -------------------------------------------------------------------------

func _build_info() -> Control:
	var board := UiKit.signboard()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	board.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UiKit.GAP_L)
	v.add_child(head)
	_head = head
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 6)
	head.add_child(text)
	head.add_child(_build_art())
	_world_caption = UiKit.label("", UiKit.SIZE_LABEL, UiKit.CYAN, true)
	text.add_child(_world_caption)
	_level_name = UiKit.sign_label("", NAME_FONT)
	_level_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_level_name.mouse_filter = Control.MOUSE_FILTER_PASS
	_level_name.resized.connect(_fit_name)
	text.add_child(_level_name)
	_blurb = UiKit.body("", 420)
	_blurb.max_lines_visible = BLURB_LINES
	_blurb.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_blurb.mouse_filter = Control.MOUSE_FILTER_PASS
	text.add_child(_blurb)
	text.add_child(_build_lock())
	_level_tabs = HBoxContainer.new()
	_level_tabs.add_theme_constant_override("separation", UiKit.GAP_S)
	v.add_child(_level_tabs)
	v.add_child(UiKit.spacer(2))
	_stats = HBoxContainer.new()
	_stats.add_theme_constant_override("separation", UiKit.GAP_M)
	v.add_child(_stats)
	v.add_child(UiKit.spacer(2))
	_who = UiKit.section("WHO IS WAITING")
	v.add_child(_who)
	_enemies = HFlowContainer.new()
	_enemies.add_theme_constant_override("h_separation", UiKit.GAP_S)
	_enemies.add_theme_constant_override("v_separation", UiKit.GAP_S)
	_enemies.resized.connect(_fit_enemies)
	v.add_child(_enemies)
	_endless_box = VBoxContainer.new()
	_endless_box.add_theme_constant_override("separation", UiKit.GAP_S)
	_endless_box.visible = false
	v.add_child(_endless_box)
	v.add_child(UiKit.filler())
	return board


## The amber callout of a locked world: padlock and what opens it.
func _build_lock() -> Control:
	_lock = UiKit.neon_panel(UiKit.AMBER)
	_lock.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiKit.GAP_M)
	_lock.add_child(row)
	row.add_child(UiKit.icon(&"icon_lock", 40.0))
	_lock_text = UiKit.sign_label("", 30, UiKit.AMBER)
	row.add_child(_lock_text)
	return _lock


## The level's key art in a rounded frame (hidden for a level without one).
func _build_art() -> Control:
	_art = TextureRect.new()
	_art.custom_minimum_size = ART_SIZE
	_art.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load(KeyArt.CARD_SHADER)
	m.set_shader_parameter("rect_size", ART_SIZE)
	m.set_shader_parameter("radius", 18.0)
	m.set_shader_parameter("shade_amount", 0.0)
	_art.material = m
	return _art


## Loadout, difficulty and DEPLOY.
func _build_side() -> Control:
	var board := UiKit.signboard()
	board.custom_minimum_size.x = 600
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", UiKit.GAP_S)
	board.add_child(v)
	for slot in 2:
		var plate := UiKit.slot_plate("%s [%d]" % [String(Loadout.SLOT_NAMES[slot]).to_upper(), slot + 1], "")
		plate.active = slot == 0
		v.add_child(plate)
		_plates.append(plate)
	if GameData.ui_extensions(UiExtension.Kind.MENU_PAGE).any(func(e: UiExtension): return e.id == &"arsenal"):
		var arsenal := UiKit.sign_button("CHANGE LOADOUT", SignButton.Kind.SECONDARY, 24)
		arsenal.pressed.connect(func(): open_page.emit(&"arsenal"))
		v.add_child(arsenal)
	v.add_child(UiKit.section("DIFFICULTY"))
	_difficulty = UiKit.tabs(26)
	for id in Difficulty.IDS:
		var tab := _difficulty.add_tab(id, Difficulty.label(id))
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not Difficulty.is_unlocked(id):
			tab.modulate.a = 0.5
			tab.tooltip_text = Difficulty.lock_reason(id)
	_difficulty.tab_changed.connect(_on_difficulty)
	v.add_child(_difficulty)
	_difficulty_note = UiKit.body("", 520, UiKit.SIZE_SMALL, UiKit.MUTED)
	v.add_child(_difficulty_note)
	v.add_child(UiKit.filler())
	_deploy = UiKit.sign_button("DEPLOY", SignButton.Kind.PRIMARY, 60)
	_deploy.custom_minimum_size.y = 96
	_deploy.pressed.connect(start)
	v.add_child(_deploy)
	return board


## The band under the boards: the pips, then the tray of cards between the arrows.
func _build_carousel() -> Control:
	_carousel = Control.new()
	_carousel.custom_minimum_size.y = PIP_ROW + tray_height()
	# Clicks, drags and the wheel; the cards only take hover.
	_carousel.mouse_filter = Control.MOUSE_FILTER_STOP
	_carousel.gui_input.connect(_on_carousel_input)
	_carousel.resized.connect(_layout_band)
	_tray = Control.new()
	_tray.clip_contents = true
	_tray.mouse_filter = Control.MOUSE_FILTER_PASS
	_tray.draw.connect(_draw_tray)
	_tray.resized.connect(_on_tray_resized)
	_carousel.add_child(_tray)
	_tray_box.bg_color = Color(UiKit.INK, 0.55)
	_tray_box.border_color = Color(1, 1, 1, 0.1)
	_tray_box.set_border_width_all(2)
	_tray_box.set_corner_radius_all(18)
	for i in GameData.worlds().size():
		var card := WorldCard.new()
		card.world = GameData.worlds()[i]
		card.index = i
		_tray.add_child(card)
		_cards.append(card)
	for i in GameData.endless_levels().size():
		var card := EndlessCard.make(GameData.endless_levels()[i], i)
		_tray.add_child(card)
		_cards.append(card)
	for side in [-1, 1]:
		var arrow := UiKit.icon_button(&"icon_arrow_left" if side < 0 else &"icon_arrow_right", "Previous world" if side < 0 else "Next world")
		arrow.custom_minimum_size = ARROW_SIZE
		arrow.pressed.connect(step_world.bind(side))
		_carousel.add_child(arrow)
		_arrows.append(arrow)
	_pips = Control.new()
	_pips.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_pips.offset_bottom = PIP_ROW
	_pips.mouse_filter = Control.MOUSE_FILTER_STOP
	_pips.draw.connect(_draw_pips)
	_pips.gui_input.connect(_on_pips_input)
	_carousel.add_child(_pips)
	_scroll = _slot()
	return _carousel


## Height of the card tray: the selected card and its padding.
static func tray_height() -> float:
	return ceilf(WorldCard.SIZE.y * CARD_SCALE + TRAY_PAD * 2.0)


## Half the width the five nearest cards take in the tray (with a gap at
## each end), for a selected card `width` wide.
func _row_half(width: float) -> float:
	return _depth_offset(2.0, width) + DEPTH_SCALE[2] * width * 0.5 + CARD_GAP


## The tray is centred under the pips, as wide as the five nearest cards (or
## the band less the arrows, when narrower), with an arrow just outside each
## end, centred on it.
func _layout_band() -> void:
	var band := _carousel.size
	var room := band.x - 2.0 * (ARROW_SIZE.x + UiKit.GAP_M)
	var w := minf(room, ceilf(2.0 * _row_half(WorldCard.SIZE.x * CARD_SCALE)))
	_tray.position = Vector2(roundf((band.x - w) * 0.5), PIP_ROW)
	_tray.size = Vector2(w, band.y - PIP_ROW)
	var y := PIP_ROW + (_tray.size.y - ARROW_SIZE.y) * 0.5
	_arrows[0].position = Vector2(_tray.position.x - UiKit.GAP_M - ARROW_SIZE.x, y)
	_arrows[1].position = Vector2(_tray.position.x + w + UiKit.GAP_M, y)
	for arrow in _arrows:
		arrow.size = ARROW_SIZE


func _on_tray_resized() -> void:
	_place_cards(_scroll)
	_tray.queue_redraw()


# --- selection ----------------------------------------------------------------------

## Shows story world `i` (switching to STORY).
func select_world(i: int) -> void:
	if i < 0 or i >= GameData.worlds().size():
		return
	var changed := i != world_index or mode != STORY
	if changed:
		UiSound.select()
	world_index = i
	Profile.section("menu")["world"] = i
	_show_mode(STORY, changed)


## Shows the row of mode `id` (STORY or ENDLESS) at the slot browsed last.
func select_mode(id: StringName) -> void:
	if id == ENDLESS and GameData.endless_levels().is_empty():
		id = STORY
	if id != mode:
		UiSound.tab()
	_show_mode(id, id != mode)


func _show_mode(id: StringName, changed: bool) -> void:
	var switched := id != mode
	mode = id
	Profile.section("menu")["mode"] = String(id)
	selected_level = null
	if switched:
		# The new row starts where it was left, without gliding across.
		_scroll = _slot()
	_refresh_mode_tiles()
	_refresh_details()
	_layout_cards(not switched)
	if changed:
		_animate_details()
		if switched:
			_deal_row()
	world_changed.emit(selected_level)


## Picks slot `i` of the current mode's row.
func _select_slot(i: int) -> void:
	if mode == STORY:
		select_world(i)
		return
	if i < 0 or i >= GameData.endless_levels().size():
		return
	var changed := i != endless_index
	if changed:
		UiSound.select()
	endless_index = i
	Profile.section("menu")["endless"] = i
	_show_mode(ENDLESS, changed)


## The tabs follow the mode; the prompts and the carousel's arrows and pips suit it.
func _refresh_mode_tiles() -> void:
	var worlds := GameData.worlds()
	for tile in _mode_tiles:
		tile.set_pressed_no_signal(tile.mode == mode)
		tile.refresh_state()
		if tile.mode == ENDLESS:
			var best := EndlessRecords.best_wave()
			tile.set_note("BEST WAVE %d" % best if best > 0 else "WAVES WITHOUT END")
			tile.set_new(endless_is_new())
		else:
			var cleared := worlds.filter(func(w: WorldData) -> bool: return WorldCard.world_stars(w) >= 3).size()
			tile.set_note("%d WORLDS  ·  %d CLEARED" % [worlds.size(), cleared])
	if _browse_prompt:
		_browse_prompt.visible = mode == STORY
		(_deploy_prompt.get_child(1) as Label).text = "Start" if mode == ENDLESS else "Deploy"
	var browse := _slot_count() > 1
	for arrow in _arrows:
		arrow.visible = browse
	if _pips:
		_pips.visible = browse
		# A lone endless level needs no row: its card sits on the board.
		_carousel.visible = mode == STORY or browse


## The cards of a newly shown row deal in.
func _deal_row() -> void:
	if not is_visible_in_tree():
		return
	var i := 0
	# A fade only: the cards keep the size and place the tray gives them.
	for card in _cards:
		if card.visible:
			var target := card.modulate.a
			card.modulate.a = 0.0
			card.create_tween().tween_property(card, "modulate:a", target, 0.18).set_delay(i * 0.05)
			i += 1


func step_world(step: int) -> void:
	var n := _slot_count()
	if n > 1:
		_select_slot(posmod(_slot() + step, n))


func select_level(level: LevelData) -> void:
	selected_level = level
	_refresh_details()
	world_changed.emit(level)


## Starts the selected level (the shell's DEPLOY and the dev driver call this).
func start() -> void:
	if selected_level == null:
		return
	if selected_level.endless:
		Profile.section("menu")["endless_started"] = true
	Profile.save_profile()
	Sfx.play(&"deploy", -2.0)
	# The saved Loadout, unless a dev run picked a weapon.
	var weapon := selected_weapon if Game.has_node("DevDriver") else &""
	Game.start_level(selected_level.id, weapon)


func _on_difficulty(id: StringName) -> void:
	if not Difficulty.is_unlocked(id):
		# Stay on the current tier; say how to open this one.
		_difficulty.select(Difficulty.current())
		_difficulty_note.text = Difficulty.lock_reason(id)
		UiSound.deny()
		return
	Difficulty.set_current(id)
	_difficulty_note.text = Difficulty.description(id)


## The level shown for the current world: the chosen one, else its first
## unlocked level, else its first level.
func _resolve_level(world: WorldData) -> void:
	if selected_level and selected_level.world == world:
		return
	selected_level = null
	for l in world.levels:
		if GameData.is_level_unlocked(l):
			selected_level = l
			break
	if selected_level == null and not world.levels.is_empty():
		selected_level = world.levels[0]


func _refresh_details() -> void:
	var worlds := GameData.worlds()
	if worlds.is_empty():
		return
	world_index = clampi(world_index, 0, worlds.size() - 1)
	_who.visible = mode == STORY
	_enemies.visible = _who.visible
	_endless_box.visible = not _who.visible
	if mode == ENDLESS:
		_refresh_endless(GameData.endless_levels()[endless_index])
		return
	var world := worlds[world_index]
	_resolve_level(world)
	var level := selected_level
	var unlocked := level != null and GameData.is_level_unlocked(level)
	_world_caption.text = "WORLD %d  ·  %s" % [world_index + 1, world.display_name.to_upper()]
	_world_caption.add_theme_color_override("font_color", world.secondary_color)
	_set_name(level.display_name.to_upper() if level else "COMING SOON", level.blurb if level and level.blurb != "" else world.blurb)
	_art.texture = KeyArt.texture(level)
	_art.visible = _art.texture != null
	(_art.material as ShaderMaterial).set_shader_parameter("saturation", 1.0 if unlocked else 0.25)
	if _hero:
		_hero.visible = false
	_fill_level_tabs(world, level)
	_fill_stats(world, level, unlocked)
	_fill_enemies(level)
	_lock_text.text = "" if unlocked or level == null else GameData.lock_reason(level).to_upper()
	_lock.visible = _lock_text.text != ""
	_deploy.disabled = not unlocked
	_deploy.text = "DEPLOY" if unlocked else "LOCKED"
	for slot in 2:
		var w := GameData.weapon(Loadout.slot(slot))
		_plates[slot].set_value(w.display_name.to_upper() if w else "EMPTY")
		_plates[slot].set_note("%s  ·  %s" % [w.category, UiKit.rank_name(Mastery.rank(w.id), w.max_rank()).capitalize()] if w else "")


## The Endless board: records, districts and the reward track.
func _refresh_endless(level: LevelData) -> void:
	selected_level = level
	_world_caption.text = "NEW MODE  ·  ENDLESS  ·  OPEN FROM LEVEL 1" if endless_is_new() else "ENDLESS MODE  ·  OPEN FROM LEVEL 1"
	_world_caption.add_theme_color_override("font_color", EndlessCard.EMBER)
	_set_name(level.display_name.to_upper(), level.blurb)
	_art.visible = false
	_show_hero(level)
	_level_tabs.visible = false
	_lock.visible = false
	var unlocked := GameData.is_level_unlocked(level)
	_deploy.disabled = not unlocked
	_deploy.text = "START" if unlocked else "COMING SOON"
	_clear(_stats)
	_best_value = null
	_star_row = null
	var accent := level.accent_color
	var rules := level.endless
	_stats.add_child(_stat_tile("BEST WAVE", str(EndlessRecords.best_wave()), accent))
	_stats.add_child(_stat_tile("BEST SCORE", ScorePanel._fmt(EndlessRecords.best_score()), accent))
	var gated := rules.districts.filter(func(d: EndlessDistrict) -> bool: return d.price > 0).size()
	_stats.add_child(_stat_tile("DISTRICTS", "%d / %d" % [EndlessRecords.opened_count(rules), gated], accent))
	_stats.add_child(_stat_tile("ON %s" % Difficulty.label(Difficulty.current()), "WAVE %d" % EndlessRecords.best_on(Difficulty.current()), Difficulty.color(Difficulty.current())))
	_fill_endless(rules)
	for slot in 2:
		var w := GameData.weapon(Loadout.slot(slot))
		_plates[slot].set_value(w.display_name.to_upper() if w else "EMPTY")
		_plates[slot].set_note("%s  ·  %s" % [w.category, UiKit.rank_name(Mastery.rank(w.id), w.max_rank()).capitalize()] if w else "")


## The card of endless `level` in the key art's place, picked (bulbs on).
func _show_hero(level: LevelData) -> void:
	if _hero and _hero.level != level:
		_hero.queue_free()
		_hero = null
	if _hero == null:
		_hero = EndlessCard.make(level, 0)
		_hero.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		# The board's card is to look at: the carousel handles the input.
		_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_head.add_child(_hero)
	else:
		_hero.refresh()
	_hero.visible = true
	_hero.selected = true


## The districts (with their prices) and the reward track.
func _fill_endless(rules: EndlessRules) -> void:
	_clear(_endless_box)
	_endless_box.add_child(UiKit.section("THE CITY", "pay tickets at a gate to open a district"))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", UiKit.GAP_S)
	row.add_theme_constant_override("v_separation", UiKit.GAP_S)
	_endless_box.add_child(row)
	for d in rules.districts:
		var note := "START" if d.price == 0 else "%d TICKETS" % d.price
		var lit := d.price == 0 or EndlessRecords.has_opened(d.id)
		row.add_child(_pill(d.display_name.to_upper(), note, d.accent_color, lit, UiKit.AMBER if d.price > 0 else UiKit.GREEN))
	_endless_box.add_child(UiKit.section("REWARD TRACK", "", UiKit.AMBER))
	var track := HFlowContainer.new()
	track.add_theme_constant_override("h_separation", UiKit.GAP_S)
	track.add_theme_constant_override("v_separation", UiKit.GAP_S)
	_endless_box.add_child(track)
	var rewards := EndlessRewards.track(rules)
	if rewards.is_empty():
		track.add_child(UiKit.body("Rewards arrive with the city's camos, its weapon and its Mythic finish.", 0, UiKit.SIZE_SMALL, UiKit.MUTED))
	for e in rewards:
		track.add_child(_reward_chip(e))
	_endless_box.add_child(UiKit.section("HOW IT PLAYS", "", EndlessCard.EMBER))
	var rules_row := HFlowContainer.new()
	rules_row.add_theme_constant_override("h_separation", UiKit.GAP_S)
	rules_row.add_theme_constant_override("v_separation", UiKit.GAP_S)
	_endless_box.add_child(rules_row)
	for r in HOW_IT_PLAYS:
		rules_row.add_child(_pill(r[0], r[1], EndlessCard.EMBER, true, UiKit.CREAM))


## A dark pill: a `title` in `accent` (muted unless `lit`), then a note.
func _pill(title: String, note: String, accent: Color, lit: bool, note_color: Color) -> Control:
	var pill := PanelContainer.new()
	var box := UiKit.box(Color("2c2257"), Color(accent, 0.9 if lit else 0.35), 22, 2, 0)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	pill.add_theme_stylebox_override("panel", box)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	pill.add_child(r)
	r.add_child(UiKit.label(title, 20, accent.lerp(Color.WHITE, 0.4) if lit else UiKit.MUTED, true))
	r.add_child(UiKit.label(note, 18, note_color, true))
	return pill


## One reward: what it is, in its rarity colour, and what earns it.
func _reward_chip(e: Dictionary) -> Control:
	var met := bool(e["met"])
	var color: Color = e["color"]
	var card := PanelContainer.new()
	var box := UiKit.box(Color("2c2257") if met else Color(UiKit.INK, 0.85), Color(color, 0.95 if met else 0.45), 14, 2, 0)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	card.add_theme_stylebox_override("panel", box)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.custom_minimum_size = Vector2(196, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -6)
	card.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	v.add_child(top)
	top.add_child(UiKit.label(String(e["goal"]), 16, UiKit.GREEN if met else UiKit.AMBER, true))
	if met:
		top.add_child(HudIcon.make(&"check", 18.0, UiKit.GREEN))
	v.add_child(UiKit.label(String(e["name"]).to_upper(), 20, color.lerp(Color.WHITE, 0.35) if met else UiKit.CREAM, true))
	v.add_child(UiKit.label(String(e["kind"]), 16, color if met else UiKit.MUTED))
	return card


func _fill_level_tabs(world: WorldData, level: LevelData) -> void:
	_clear(_level_tabs)
	_level_tabs.visible = world.levels.size() > 1
	if not _level_tabs.visible:
		return
	var group := ButtonGroup.new()
	for l in world.levels:
		var tab := UiKit.toggle_button(l.display_name.to_upper(), group, 22)
		tab.set_pressed_no_signal(l == level)
		tab.pressed.connect(select_level.bind(l))
		_level_tabs.add_child(tab)


func _fill_stats(world: WorldData, level: LevelData, unlocked: bool) -> void:
	_clear(_stats)
	_best_value = null
	_star_row = null
	if level == null:
		return
	var waves := level.wave_set.waves.size() if level.wave_set else 0
	_stats.add_child(_stat_tile("WAVES", str(waves), world.accent_color))
	var best := _stat_tile("BEST SCORE", ScorePanel._fmt(Profile.best_score(level.id)), world.accent_color)
	_best_value = best.get_child(0).get_child(1) as Label
	_stats.add_child(best)
	_stats.add_child(_stat_tile("BEST WAVE", "%d / %d" % [mini(Profile.best_wave(level.id), waves), waves], world.accent_color))
	var status := "CLEARED" if Profile.is_level_completed(level.id) else ("OPEN" if unlocked else "LOCKED")
	var tile := _stat_tile(status, "", world.secondary_color)
	_star_row = WorldCard.star_row(WorldCard.stars(level), 38.0)
	tile.get_child(0).add_child(_star_row)
	_stats.add_child(tile)


## A new world was picked: its art and name fade up, the best score counts
## up and the stars pop in one after another.
func _animate_details() -> void:
	if not is_visible_in_tree():
		return
	UiFx.fade_in(_hero if mode == ENDLESS and _hero else _art, 0.25)
	UiFx.fade_in(_level_name, 0.2)
	if _best_value and selected_level:
		UiFx.count_up(_best_value, 0, Profile.best_score(selected_level.id), 0.6, func(n: int) -> String: return ScorePanel._fmt(n))
	if _star_row:
		for i in _star_row.get_child_count():
			var star := _star_row.get_child(i) as Control
			star.pivot_offset = star.custom_minimum_size * 0.5
			UiFx.pop_in(star, 0.12 + i * 0.09, 0.3)


## The enemy kinds of the level's waves, in order of first appearance, with
## how many of each come, then its boss.
func _fill_enemies(level: LevelData) -> void:
	_clear(_enemies)
	if level == null or level.wave_set == null:
		return
	var counts := {}
	var bosses: Array[StringName] = []
	for wave in level.wave_set.waves:
		for id in wave.spawns:
			counts[StringName(id)] = int(counts.get(StringName(id), 0)) + int(wave.spawns[id])
		if wave.boss != &"" and not wave.boss in bosses:
			bosses.append(wave.boss)
	var ids := counts.keys()
	_enemy_kinds = ids.size()
	for i in mini(ids.size(), ENEMY_CHIPS):
		_enemies.add_child(_enemy_chip(ids[i], "×%d" % counts[ids[i]], false))
	_more_chip = UiKit.chip("", UiKit.AMBER, 22, false)
	_enemies.add_child(_more_chip)
	for id in bosses:
		_enemies.add_child(_enemy_chip(id, "BOSS", true))
	_fit_enemies()


## Shows as many enemy kinds as fit in ENEMY_ROWS rows with the bosses (the
## others are counted on the "+N MORE" chip).
func _fit_enemies() -> void:
	if _more_chip == null or not is_instance_valid(_more_chip):
		return
	var chips := _enemies.get_children().filter(func(c: Node) -> bool: return c != _more_chip)
	var count := mini(_enemy_kinds, ENEMY_CHIPS)
	var kinds: Array[Control] = []
	kinds.assign(chips.slice(0, count))
	var bosses: Array[Control] = []
	bosses.assign(chips.slice(count))
	var width := _enemies.size.x
	var shown := kinds.size()
	while shown > 0 and width > 0.0:
		var hidden := _enemy_kinds - shown
		_more_chip.set_text("+%d MORE" % hidden)
		var row: Array[Control] = kinds.slice(0, shown)
		if hidden > 0:
			row.append(_more_chip)
		row.append_array(bosses)
		if _flow_rows(row, width) <= ENEMY_ROWS:
			break
		shown -= 1
	for i in kinds.size():
		kinds[i].visible = i < shown
	_more_chip.set_text("+%d MORE" % (_enemy_kinds - shown))
	_more_chip.visible = shown < _enemy_kinds


## Rows an HFlowContainer `width` wide takes for `items`.
func _flow_rows(items: Array[Control], width: float) -> int:
	var gap := float(UiKit.GAP_S)
	var rows := 0
	var x := 0.0
	for c in items:
		var w := c.get_combined_minimum_size().x
		if rows == 0 or x + gap + w > width:
			rows += 1
			x = w
		else:
			x += gap + w
	return rows


## Sets the level's name and blurb (each in full in its tooltip).
func _set_name(title: String, blurb: String) -> void:
	_level_name.text = title
	_level_name.tooltip_text = title
	_blurb.text = blurb
	_blurb.tooltip_text = blurb
	_fit_name()


## The name's font shrinks until the name fits on its line.
func _fit_name() -> void:
	var font := _level_name.get_theme_font("font")
	var width := _level_name.size.x
	if font == null or width <= 0.0:
		return
	var size := NAME_FONT
	while size > NAME_FONT_MIN and font.get_string_size(_level_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		size -= 2
	_level_name.add_theme_font_size_override("font_size", size)


## A pill with a zombie in the enemy's shirt colour, its name and a note.
func _enemy_chip(id: StringName, note: String, boss: bool) -> Control:
	var enemy := GameData.enemy(id)
	var pill := PanelContainer.new()
	var box := UiKit.box(Color("2c2257"), UiKit.AMBER if boss else Color(1, 1, 1, 0.14), 22, 2, 0)
	box.content_margin_left = 8
	box.content_margin_right = 14
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	pill.add_theme_stylebox_override("panel", box)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	pill.add_child(row)
	var tint := UiKit.AMBER if boss else (enemy.shirt_colors[0] if enemy and not enemy.shirt_colors.is_empty() else UiKit.CREAM)
	var icon := HudIcon.make(&"zombie", 28.0, tint.lightened(0.2))
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	row.add_child(UiKit.label(enemy.display_name.to_upper() if enemy else String(id).to_upper(), 20, UiKit.CREAM, true))
	row.add_child(UiKit.label(note, 20, UiKit.AMBER if boss else UiKit.MUTED, true))
	return pill


func _stat_tile(caption: String, value: String, accent: Color) -> PanelContainer:
	var box := UiKit.card_panel()
	box.custom_minimum_size = Vector2(170, 84)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", -6)
	box.add_child(v)
	var c := UiKit.label(caption, 18, accent, true)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(c)
	if value != "":
		var val := UiKit.label(value, 34, Color.WHITE, true)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(val)
	return box


## Points the carousel at the selected world: the cards glide there (or jump,
## when not animated) and the accent pool under them changes colour.
func _layout_cards(animate: bool) -> void:
	var at := _slot()
	for card in _cards:
		card.selected = _in_row(card) and card.index == at
	_pips.queue_redraw()
	if _glide and _glide.is_valid():
		_glide.kill()
	_tint_glow(animate)
	if not animate or not is_visible_in_tree():
		_place_cards(at)
		return
	var seconds := clampf(GLIDE + absf(at - _scroll) * 0.03, GLIDE, 0.7)
	_glide = create_tween()
	_glide.tween_method(_place_cards, _scroll, float(at), seconds).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


## Places every card for carousel position `at` (in worlds) in the tray: the
## nearest is the largest, the others shrink (DEPTH_SCALE), dim, tilt a little
## and fade out past the second; all are centred on the tray's middle line, so
## each fits its height whole, and their art slides behind the frame. Scales
## and offsets are blended linearly between whole positions, which keeps the
## gap between neighbours constant while they glide.
func _place_cards(at: float) -> void:
	_scroll = at
	if _tray == null:
		return
	var tray := _tray.size if _tray.size.x > 0.0 else Vector2(2.0 * _row_half(WorldCard.SIZE.x * CARD_SCALE), tray_height())
	var width := WorldCard.SIZE.x * CARD_SCALE
	# A narrow tray shrinks the row so the five nearest cards fit inside.
	var fit := minf(1.0, tray.x * 0.5 / _row_half(width))
	var mid := tray * 0.5
	for card in _cards:
		var d := card.index - at
		var ad := absf(d)
		card.visible = _in_row(card) and ad < CARDS_AROUND
		if not card.visible:
			continue
		var k := _depth_scale(ad) * CARD_SCALE * fit
		card.scale = Vector2(k, k)
		card.pivot_offset = WorldCard.SIZE * 0.5
		card.position = Vector2(mid.x + signf(d) * _depth_offset(ad, width) * fit, mid.y) - WorldCard.SIZE * 0.5
		card.rotation = clampf(d, -2.0, 2.0) * deg_to_rad(1.4)
		card.z_index = 10 - roundi(ad * 3.0)
		var shade := lerpf(1.0, 0.72, minf(ad, 1.0)) - 0.12 * clampf(ad - 1.0, 0.0, 1.0)
		card.modulate = Color(shade, shade, shade + 0.06 * minf(ad, 1.0), 1.0 - smoothstep(2.0, CARDS_AROUND, ad))
		card.mouse_filter = Control.MOUSE_FILTER_PASS if ad < 2.1 else Control.MOUSE_FILTER_IGNORE
		card.set_depth(d)


## Relative scale of a card `ad` positions from the selected one.
func _depth_scale(ad: float) -> float:
	var n := mini(floori(ad), DEPTH_SCALE.size() - 2)
	return lerpf(DEPTH_SCALE[n], DEPTH_SCALE[n + 1], minf(ad - n, 1.0))


## How far the centre of a card `ad` positions from the selected one sits
## from the tray's middle, for a selected card `width` wide.
func _depth_offset(ad: float, width: float) -> float:
	var n := mini(floori(ad), DEPTH_SCALE.size() - 2)
	var x := 0.0
	for i in n:
		x += (DEPTH_SCALE[i] + DEPTH_SCALE[i + 1]) * width * 0.5 + CARD_GAP
	return x + ((DEPTH_SCALE[n] + DEPTH_SCALE[n + 1]) * width * 0.5 + CARD_GAP) * minf(ad - n, 1.0)


func _world_accent() -> Color:
	var worlds := GameData.worlds()
	if mode == ENDLESS:
		return GameData.endless_levels()[endless_index].accent_color
	return worlds[world_index].accent_color if world_index < worlds.size() else UiKit.CYAN


## The pool of the selected world's accent under the cards fades to its
## colour (amber while the world is locked).
func _tint_glow(animate: bool) -> void:
	var target := _world_accent()
	if mode == STORY and world_index < GameData.worlds().size() and not GameData.is_world_unlocked(GameData.worlds()[world_index]):
		target = UiKit.AMBER.darkened(0.3)
	if _glow_tween and _glow_tween.is_valid():
		_glow_tween.kill()
	if not animate or not is_visible_in_tree():
		_glow_color = target
		_tray.queue_redraw()
		return
	_glow_tween = create_tween()
	_glow_tween.tween_method(_set_glow, _glow_color, target, 0.35)


func _set_glow(c: Color) -> void:
	_glow_color = c
	_tray.queue_redraw()


# --- carousel input -----------------------------------------------------------------

## The wheel steps, a drag scrubs (and snaps to the nearest world on
## release), a click picks the card or pip under it.
func _on_carousel_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT]:
		step_world(-1)
	elif mb and mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT]:
		step_world(1)
	elif mb and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		_dragging = true
		_drag_moved = false
		_drag_x = mb.position.x
		_drag_scroll = _scroll
	elif mb and mb.button_index == MOUSE_BUTTON_LEFT and _dragging:
		_dragging = false
		if _drag_moved:
			_select_slot(clampi(roundi(_scroll), 0, _slot_count() - 1))
		else:
			_click(mb.position)
	elif event is InputEventMouseMotion and _dragging:
		_drag_to((event as InputEventMouseMotion).position.x - _drag_x)
	else:
		return
	_carousel.accept_event()


## Follows a drag `dx` pixels long (past a small dead zone).
func _drag_to(dx: float) -> void:
	if absf(dx) > 10.0:
		_drag_moved = true
	if not _drag_moved:
		return
	if _glide and _glide.is_valid():
		_glide.kill()
	_place_cards(clampf(_drag_scroll - dx / _depth_offset(1.0, WorldCard.SIZE.x * CARD_SCALE), -0.45, _slot_count() - 0.55))


func _on_pips_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var x0 := _pips.size.x * 0.5 - PIP_STEP * (_slot_count() - 1) * 0.5
		var i := roundi((mb.position.x - x0) / PIP_STEP)
		if i >= 0 and i < _slot_count():
			_select_slot(i)
		_pips.accept_event()


func _click(at: Vector2) -> void:
	# The card nearest the middle wins where they overlap.
	var order := _cards.filter(func(c: WorldCard) -> bool: return c.visible and _in_row(c) and c.mouse_filter != Control.MOUSE_FILTER_IGNORE)
	order.sort_custom(func(a: WorldCard, b: WorldCard) -> bool: return absf(a.index - _scroll) < absf(b.index - _scroll))
	for card: WorldCard in order:
		var local := card.get_transform().affine_inverse() * (at - _tray.position)
		if Rect2(Vector2.ZERO, WorldCard.SIZE).has_point(local):
			_select_slot(card.index)
			return


# --- drawing ------------------------------------------------------------------------

## The tray's dark box and the pool of the selected world's accent in it,
## under the cards.
func _draw_tray() -> void:
	var box := Rect2(Vector2.ZERO, _tray.size)
	_tray.draw_style_box(_tray_box, box)
	var pool := Vector2(WorldCard.SIZE.x * CARD_SCALE * 2.4, _tray.size.y * 1.3)
	_tray.draw_texture_rect(_glow_texture(), Rect2(box.get_center() - pool * 0.5, pool), false, Color(_glow_color, 0.5))


## One pip per slot of the row on a dark pill: a world's is gold once
## cleared, dim with an amber ring while locked, the selected one large in
## its accent; an endless level's is the Endless emblem.
func _draw_pips() -> void:
	var worlds := GameData.worlds()
	var n := _slot_count()
	var x0 := _pips.size.x * 0.5 - PIP_STEP * (n - 1) * 0.5
	var y := _pips.size.y * 0.5
	var pill := Rect2(x0 - 20.0, y - 11.0, PIP_STEP * (n - 1) + 40.0, 22.0)
	_pip_box.bg_color = Color(UiKit.INK, 0.75)
	_pip_box.set_corner_radius_all(11)
	_pips.draw_style_box(_pip_box, pill)
	if mode == ENDLESS:
		for i in n:
			EndlessEmblem.paint(_pips, Vector2(x0 + i * PIP_STEP, y), 13.0 if i == endless_index else 9.0, 1.0 if i == endless_index else 0.6)
		return
	for i in worlds.size():
		var at := Vector2(x0 + i * PIP_STEP, y)
		if i == world_index:
			_pips.draw_circle(at, 14.0, Color(worlds[i].accent_color, 0.35), true, -1.0, true)
			_pips.draw_circle(at, 9.0, worlds[i].accent_color, true, -1.0, true)
			_pips.draw_circle(at, 9.0, UiKit.CREAM, false, 3.0, true)
		elif not GameData.is_world_unlocked(worlds[i]):
			_pips.draw_circle(at, 6.0, Color(UiKit.AMBER, 0.55), false, 2.0, true)
		else:
			var cleared := WorldCard.world_stars(worlds[i]) >= 3
			_pips.draw_circle(at, 7.0, Wallet.COLOR if cleared else UiKit.CREAM, true, -1.0, true)


## A soft white disc fading to nothing at its rim (tinted when drawn).
static func _glow_texture() -> GradientTexture2D:
	if _glow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.45))
		_glow_tex = GradientTexture2D.new()
		_glow_tex.gradient = g
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(1.0, 0.5)
		_glow_tex.width = 128
		_glow_tex.height = 128
	return _glow_tex


static func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()
