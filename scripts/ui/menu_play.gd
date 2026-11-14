class_name MenuPlay
extends MenuPage
## The Play page: pick a world from the carousel of key-art cards (locked
## ones show what opens them), read the level's details, best results,
## progress stars and the zombies that wait there, choose the difficulty,
## check the loadout and DEPLOY. Left/right (or A/D) browse the worlds.

## The world in the carousel changed: the shell cross-fades the backdrop.
signal world_changed(level: LevelData)

const ENEMY_CHIPS := 7
## Size of the level's key art on the details board.
const ART_SIZE := Vector2(448, 252)
## The row of position pips sits this far above the cards (in the gap
## between the boards and the carousel).
const PIPS_ABOVE := 8.0
## Cards further than this from the selected one are faded out, so the
## carousel shows the world, its neighbours and nothing under the arrows.
const CARDS_AROUND := 1

var selected_level: LevelData
## Starter weapon for dev runs (the saved Loadout is used otherwise).
var selected_weapon: StringName
var world_index := 0
var _cards: Array[WorldCard] = []
var _carousel: Control
var _world_caption: Label
var _level_name: Label
var _blurb: Label
var _level_tabs: HBoxContainer
var _stats: HBoxContainer
var _enemies: HFlowContainer
var _lock: Label
var _art: TextureRect
var _plates: Array[SlotPlate] = []
var _difficulty: KitTabs
var _difficulty_note: Label
var _deploy: SignButton


func _init() -> void:
	selected_weapon = StringName(String(Profile.data.get("last_weapon", "")))
	if GameData.weapon(selected_weapon) == null:
		selected_weapon = GameData.default_weapon_id()
	world_index = clampi(int(Profile.section("menu").get("world", 0)), 0, maxi(0, GameData.worlds().size() - 1))


## The level the Play page opens on: the world browsed last, its first
## unlocked level (the shell shows it behind the menu before the page exists).
static func remembered_level() -> LevelData:
	var worlds := GameData.worlds()
	if worlds.is_empty():
		return null
	var world := worlds[clampi(int(Profile.section("menu").get("world", 0)), 0, worlds.size() - 1)]
	for l in world.levels:
		if GameData.is_level_unlocked(l):
			return l
	return world.levels[0] if not world.levels.is_empty() else null


func uses_shell_header() -> bool:
	return true


func header_extra() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", UiKit.GAP_L)
	row.add_child(UiKit.key_prompt("A", "Previous world"))
	row.add_child(UiKit.key_prompt("D", "Next world"))
	row.add_child(UiKit.key_prompt("ENTER", "Deploy"))
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
	_difficulty.select(Difficulty.current())
	_difficulty_note.text = Difficulty.description(Difficulty.current())
	_refresh_details()
	_layout_cards(false)


func first_focus() -> Control:
	return _deploy


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or KitDialog.open_count > 0:
		return
	var step := 0
	if event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		step = -1
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		step = 1
	if step == 0:
		return
	# Inside the difficulty row the arrows move between its options.
	var focus := get_viewport().gui_get_focus_owner()
	if focus and _difficulty.is_ancestor_of(focus) and not (event is InputEventKey and (event as InputEventKey).physical_keycode in [KEY_A, KEY_D]):
		return
	step_world(step)
	get_viewport().set_input_as_handled()


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
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 6)
	head.add_child(text)
	head.add_child(_build_art())
	_world_caption = UiKit.label("", UiKit.SIZE_LABEL, UiKit.CYAN, true)
	text.add_child(_world_caption)
	_level_name = UiKit.sign_label("", 68)
	_level_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_level_name.add_theme_constant_override("line_spacing", -14)
	text.add_child(_level_name)
	_blurb = UiKit.body("", 420)
	text.add_child(_blurb)
	_level_tabs = HBoxContainer.new()
	_level_tabs.add_theme_constant_override("separation", UiKit.GAP_S)
	v.add_child(_level_tabs)
	v.add_child(UiKit.spacer(2))
	_stats = HBoxContainer.new()
	_stats.add_theme_constant_override("separation", UiKit.GAP_M)
	v.add_child(_stats)
	v.add_child(UiKit.spacer(2))
	v.add_child(UiKit.section("WHO IS WAITING"))
	_enemies = HFlowContainer.new()
	_enemies.add_theme_constant_override("h_separation", UiKit.GAP_S)
	_enemies.add_theme_constant_override("v_separation", UiKit.GAP_S)
	v.add_child(_enemies)
	v.add_child(UiKit.filler())
	_lock = UiKit.sign_label("", 30, UiKit.AMBER)
	v.add_child(_lock)
	return board


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
		_difficulty.add_tab(id, Difficulty.label(id)).size_flags_horizontal = Control.SIZE_EXPAND_FILL
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


func _build_carousel() -> Control:
	_carousel = Control.new()
	_carousel.custom_minimum_size.y = WorldCard.SIZE.y + 14
	_carousel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_carousel.draw.connect(_draw_pips)
	for i in GameData.worlds().size():
		var card := WorldCard.new()
		card.world = GameData.worlds()[i]
		card.index = i
		card.pressed.connect(select_world.bind(i))
		_carousel.add_child(card)
		_cards.append(card)
	for side in [-1, 1]:
		var arrow := UiKit.icon_button(&"icon_arrow_left" if side < 0 else &"icon_arrow_right", "Previous world" if side < 0 else "Next world")
		arrow.custom_minimum_size = Vector2(64, 110)
		arrow.pressed.connect(step_world.bind(side))
		_carousel.add_child(arrow)
		arrow.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT if side < 0 else Control.PRESET_CENTER_RIGHT)
		arrow.grow_horizontal = Control.GROW_DIRECTION_END if side < 0 else Control.GROW_DIRECTION_BEGIN
		arrow.grow_vertical = Control.GROW_DIRECTION_BOTH
	return _carousel


# --- selection ----------------------------------------------------------------------

func select_world(i: int) -> void:
	if i < 0 or i >= GameData.worlds().size():
		return
	if i != world_index:
		UiSound.select()
	world_index = i
	Profile.section("menu")["world"] = i
	selected_level = null
	_refresh_details()
	_layout_cards(true)
	world_changed.emit(selected_level)


func step_world(step: int) -> void:
	var n := GameData.worlds().size()
	if n > 0:
		select_world(posmod(world_index + step, n))


func select_level(level: LevelData) -> void:
	selected_level = level
	_refresh_details()
	world_changed.emit(level)


## Starts the selected level (the shell's DEPLOY and the dev driver call this).
func start() -> void:
	if selected_level == null:
		return
	Profile.save_profile()
	Sfx.play(&"deploy", -2.0)
	# The saved Loadout, unless a dev run picked a weapon.
	var weapon := selected_weapon if Game.has_node("DevDriver") else &""
	Game.start_level(selected_level.id, weapon)


func _on_difficulty(id: StringName) -> void:
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
	var world := worlds[world_index]
	_resolve_level(world)
	var level := selected_level
	var unlocked := level != null and GameData.is_level_unlocked(level)
	_world_caption.text = "WORLD %d  ·  %s" % [world_index + 1, world.display_name.to_upper()]
	_world_caption.add_theme_color_override("font_color", world.secondary_color)
	_level_name.text = level.display_name.to_upper() if level else "COMING SOON"
	_blurb.text = level.blurb if level and level.blurb != "" else world.blurb
	_art.texture = KeyArt.texture(level)
	_art.visible = _art.texture != null
	(_art.material as ShaderMaterial).set_shader_parameter("saturation", 1.0 if unlocked else 0.25)
	_fill_level_tabs(world, level)
	_fill_stats(world, level, unlocked)
	_fill_enemies(level)
	_lock.text = "" if unlocked or level == null else "LOCKED  ·  " + GameData.lock_reason(level)
	_lock.visible = _lock.text != ""
	_deploy.disabled = not unlocked
	_deploy.text = "DEPLOY" if unlocked else "LOCKED"
	for slot in 2:
		var w := GameData.weapon(Loadout.slot(slot))
		_plates[slot].set_value(w.display_name.to_upper() if w else "EMPTY")
		_plates[slot].set_note("%s  ·  %s" % [w.category, UiKit.rank_name(Mastery.rank(w.id), w.max_rank()).capitalize()] if w else "")


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
	if level == null:
		return
	var waves := level.wave_set.waves.size() if level.wave_set else 0
	_stats.add_child(_stat_tile("WAVES", str(waves), world.accent_color))
	_stats.add_child(_stat_tile("BEST SCORE", ScorePanel._fmt(Profile.best_score(level.id)), world.accent_color))
	_stats.add_child(_stat_tile("BEST WAVE", "%d / %d" % [mini(Profile.best_wave(level.id), waves), waves], world.accent_color))
	var status := "CLEARED" if Profile.is_level_completed(level.id) else ("OPEN" if unlocked else "LOCKED")
	var tile := _stat_tile(status, "", world.secondary_color)
	tile.get_child(0).add_child(WorldCard.star_row(WorldCard.stars(level), 38.0))
	_stats.add_child(tile)


## The enemy kinds of the level's waves, in order of first appearance.
func _fill_enemies(level: LevelData) -> void:
	_clear(_enemies)
	if level == null or level.wave_set == null:
		return
	var seen: Array[StringName] = []
	for wave in level.wave_set.waves:
		for id in wave.spawns:
			if not StringName(id) in seen:
				seen.append(StringName(id))
	for i in mini(seen.size(), ENEMY_CHIPS):
		var enemy := GameData.enemy(seen[i])
		_enemies.add_child(UiKit.chip(enemy.display_name.to_upper() if enemy else String(seen[i]).to_upper(), Color("3a2d6b"), 22, false))
	if seen.size() > ENEMY_CHIPS:
		_enemies.add_child(UiKit.chip("+%d MORE" % (seen.size() - ENEMY_CHIPS), UiKit.AMBER, 22, false))


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


## Lays the world cards out as a carousel centred on the selected world.
func _layout_cards(animate: bool) -> void:
	_carousel.queue_redraw()
	var width := _carousel.size.x if _carousel.size.x > 0.0 else 1824.0
	var gap := 30.0
	for card in _cards:
		var offset := card.index - world_index
		var is_selected := offset == 0
		card.selected = is_selected
		var target := Vector2(width * 0.5 - WorldCard.SIZE.x * 0.5 + offset * (WorldCard.SIZE.x + gap), 0.0 if is_selected else 12.0)
		var target_scale := Vector2.ONE * (1.0 if is_selected else 0.9)
		var tint := Color.WHITE if is_selected else Color(0.72, 0.72, 0.82, 0.9 if absi(offset) <= CARDS_AROUND else 0.0)
		card.mouse_filter = Control.MOUSE_FILTER_STOP if absi(offset) <= CARDS_AROUND else Control.MOUSE_FILTER_IGNORE
		if not animate:
			card.position = target
			card.scale = target_scale
			card.modulate = tint
			continue
		var tw := card.create_tween().set_parallel(true)
		tw.tween_property(card, "position", target, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "scale", target_scale, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "modulate", tint, 0.2)


## One pip per world over the cards: where the selected world sits among them.
func _draw_pips() -> void:
	var worlds := GameData.worlds()
	var step := 30.0
	var y := -PIPS_ABOVE
	var x0 := _carousel.size.x * 0.5 - step * (worlds.size() - 1) * 0.5
	for i in worlds.size():
		var at := Vector2(x0 + i * step, y)
		if i == world_index:
			_carousel.draw_circle(at, 8.0, worlds[i].accent_color)
			_carousel.draw_circle(at, 8.0, UiKit.CREAM, false, 3.0, true)
		else:
			_carousel.draw_circle(at, 6.0, Color(UiKit.CREAM, 0.85 if GameData.is_world_unlocked(worlds[i]) else 0.4), true, -1.0, true)


static func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()
