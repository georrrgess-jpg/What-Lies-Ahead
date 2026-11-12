class_name LockerPage
extends MenuPage
## The Locker: every cosmetic in one place. Category tabs along the top, item
## cards in a grid (rarity frames, lock state with the requirement, NEW and
## EQUIPPED badges) and a big live preview of the selected item with its
## details and Equip button. Weapon categories have a weapon selector, since
## those cosmetics are equipped per weapon. Double-click a card to equip it.

const GRID_COLUMNS := 5
const PREVIEW_SIZE := Vector2(640, 470)

var _slot: StringName = &"avatar"
var _opened := false
var _weapon_id: StringName
var _selected: CosmeticItem
var _tabs := {}
var _tab_badges := {}
var _weapon_row: VBoxContainer
var _weapon_buttons := {}
var _weapon_rank: Label
var _grid: GridContainer
var _scroll: ScrollContainer
var _cards: Array[LockerCard] = []
var _collection: Label
var _collection_bar: ProgressBar
var _thumbs: CosmeticThumbs
# Preview
var _operator_view: OperatorPreview
var _stage: LockerStage
var _card_view: Control
var _big_banner: BannerView
var _card: PlayerCard
var _big_title: Label
# Details
var _name: Label
var _rarity: Label
var _rarity_pill: PanelContainer
var _category: Label
var _description: Label
var _unlock: Label
var _unlock_bar: ProgressBar
var _equip: Button
var _unequip: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_weapon_id = StringName(String(Profile.data.get("last_weapon", "")))
	if GameData.weapon(_weapon_id) == null:
		_weapon_id = GameData.default_weapon_id()
	_thumbs = CosmeticThumbs.new()
	add_child(_thumbs)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(1790, 0)
	panel.add_child(col)
	col.add_child(_header())
	col.add_child(_tab_row())
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	col.add_child(body)
	body.add_child(_grid_column())
	body.add_child(_preview_column())
	visibility_changed.connect(func(): if not visible: Profile.save_profile())
	show_category(_slot)


func refresh() -> void:
	_opened = true
	if _grid:
		show_category(_slot)


# --- layout ---------------------------------------------------------------------

func _header() -> Control:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 20)
	var title := UiKit.label("LOCKER", 64, UiKit.AMBER, true)
	head.add_child(title)
	var progress := VBoxContainer.new()
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress.add_theme_constant_override("separation", 2)
	head.add_child(progress)
	_collection = UiKit.label("", 22, UiKit.CREAM)
	progress.add_child(_collection)
	_collection_bar = UiKit.progress(0.0, 12.0, UiKit.AMBER)
	_collection_bar.custom_minimum_size.x = 420
	_collection_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	progress.add_child(_collection_bar)
	var back_button := UiKit.soft_button("BACK", 30)
	back_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back_button.pressed.connect(func(): back.emit())
	head.add_child(back_button)
	return head


func _tab_row() -> Control:
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	var group := ButtonGroup.new()
	for cat in LockerCatalog.CATEGORIES:
		var slot: StringName = cat["slot"]
		var b := UiKit.soft_button(String(cat["label"]), 24)
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 58
		var on := UiKit.box(UiKit.PINK, UiKit.PINK_DARK, 18, 0, 8)
		on.border_width_bottom = 6
		b.add_theme_stylebox_override("pressed", on)
		b.add_theme_stylebox_override("hover_pressed", on)
		b.pressed.connect(show_category.bind(slot))
		if slot == &"avatar":
			b.name = "FirstFocus"
		var badge := PanelContainer.new()
		badge.add_theme_stylebox_override("panel", UiKit.box(UiKit.AMBER, Color.TRANSPARENT, 12, 0, 2))
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var count := UiKit.label("", 16, UiKit.INK, true)
		count.add_theme_constant_override("shadow_offset_y", 0)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.custom_minimum_size = Vector2(22, 0)
		badge.add_child(count)
		badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		badge.position = Vector2(-14, -8)
		b.add_child(badge)
		tabs.add_child(b)
		_tabs[slot] = b
		_tab_badges[slot] = count
	return tabs


func _grid_column() -> Control:
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.custom_minimum_size = Vector2(GRID_COLUMNS * LockerCard.CARD_SIZE.x + (GRID_COLUMNS - 1) * 14 + 24, 0)
	# Weapon picker: caption and mastery rank on one line, the weapon chips
	# wrapping underneath (the list grows with every weapon added).
	_weapon_row = VBoxContainer.new()
	_weapon_row.add_theme_constant_override("separation", 6)
	left.add_child(_weapon_row)
	var caption_row := HBoxContainer.new()
	_weapon_row.add_child(caption_row)
	caption_row.add_child(UiKit.label("WEAPON", 24, UiKit.CYAN, true))
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 8)
	_weapon_row.add_child(chips)
	var group := ButtonGroup.new()
	for weapon in GameData.weapons():
		var b := UiKit.soft_button(weapon.display_name, 22)
		b.toggle_mode = true
		b.button_group = group
		var on := UiKit.box(UiKit.PURPLE, Color("3d1f73"), 16, 0, 8)
		on.border_width_bottom = 5
		b.add_theme_stylebox_override("pressed", on)
		b.add_theme_stylebox_override("hover_pressed", on)
		b.pressed.connect(select_weapon.bind(weapon.id))
		chips.add_child(b)
		_weapon_buttons[weapon.id] = b
	_weapon_rank = UiKit.label("", 22, UiKit.CREAM)
	_weapon_rank.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weapon_rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	caption_row.add_child(_weapon_rank)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0, 560)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_scroll)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 8)
	pad.add_theme_constant_override("margin_top", 8)
	pad.add_theme_constant_override("margin_right", 8)
	pad.add_theme_constant_override("margin_bottom", 8)
	_scroll.add_child(pad)
	_grid = GridContainer.new()
	_grid.columns = GRID_COLUMNS
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	pad.add_child(_grid)
	return left


func _preview_column() -> Control:
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	right.custom_minimum_size = Vector2(PREVIEW_SIZE.x, 0)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = PREVIEW_SIZE
	frame.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.INK, 0.75), Color(1, 1, 1, 0.12), 22, 3, 0))
	frame.clip_contents = true
	right.add_child(frame)
	var glow := ColorRect.new()
	glow.material = _spotlight_material()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(glow)
	_operator_view = OperatorPreview.new()
	_operator_view.follow_equipped = false
	_operator_view.pedestal = true
	_operator_view.turntable_speed = 16.0
	frame.add_child(_operator_view)
	_stage = LockerStage.new()
	frame.add_child(_stage)
	frame.add_child(_card_preview())
	right.add_child(_details())
	return right


static var _spot_shader: Shader


func _spotlight_material() -> ShaderMaterial:
	if _spot_shader == null:
		_spot_shader = Shader.new()
		_spot_shader.code = """shader_type canvas_item;
void fragment() {
	vec2 d = (UV - vec2(0.5, 0.62)) * vec2(1.0, 1.4);
	float g = smoothstep(0.75, 0.0, length(d));
	COLOR = vec4(mix(vec3(0.07, 0.05, 0.18), vec3(0.42, 0.2, 0.72), g * g), 1.0);
	float rays = 0.5 + 0.5 * sin(atan(d.y, d.x) * 14.0 + TIME * 0.2);
	COLOR.rgb += vec3(0.25, 0.1, 0.35) * rays * g * 0.25;
}"""
	var m := ShaderMaterial.new()
	m.shader = _spot_shader
	return m


func _card_preview() -> Control:
	_card_view = VBoxContainer.new()
	(_card_view as VBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	(_card_view as VBoxContainer).add_theme_constant_override("separation", 22)
	_big_banner = BannerView.new(null, 22.0)
	_big_banner.custom_minimum_size = Vector2(560, 210)
	_big_banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_card_view.add_child(_big_banner)
	_big_title = UiKit.arcade_label("", 54)
	_big_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_big_title.custom_minimum_size = Vector2(560, 0)
	_big_title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_card_view.add_child(_big_title)
	_card = PlayerCard.build(true) as PlayerCard
	_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_card_view.add_child(_card)
	return _card_view


func _details() -> Control:
	var box := PanelContainer.new()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.INK, 0.7), Color.TRANSPARENT, 20, 0, 20))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	box.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	col.add_child(top)
	_name = UiKit.label("", 44, Color.WHITE, true)
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.clip_text = true
	top.add_child(_name)
	_rarity_pill = PanelContainer.new()
	_rarity_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_rarity = UiKit.label("", 20, UiKit.INK, true)
	_rarity.add_theme_constant_override("shadow_offset_y", 0)
	_rarity_pill.add_child(_rarity)
	top.add_child(_rarity_pill)
	_category = UiKit.label("", 22, UiKit.CYAN, true)
	col.add_child(_category)
	_description = UiKit.label("", 22, UiKit.CREAM)
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.custom_minimum_size = Vector2(560, 0)
	col.add_child(_description)
	col.add_child(UiKit.spacer(2))
	_unlock = UiKit.label("", 22, UiKit.AMBER, true)
	_unlock.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_unlock.custom_minimum_size = Vector2(560, 0)
	col.add_child(_unlock)
	_unlock_bar = UiKit.progress(0.0, 12.0, UiKit.AMBER)
	col.add_child(_unlock_bar)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	col.add_child(buttons)
	_equip = UiKit.button("EQUIP", 40)
	_equip.custom_minimum_size = Vector2(300, 78)
	_equip.pressed.connect(func(): _equip_item(_selected))
	buttons.add_child(_equip)
	_unequip = UiKit.soft_button("UNEQUIP", 26)
	_unequip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_unequip.pressed.connect(_unequip_slot)
	buttons.add_child(_unequip)
	return box


# --- behaviour ------------------------------------------------------------------

## Opens a category tab (by slot) and selects its equipped item.
func show_category(slot: StringName) -> void:
	_slot = slot
	# set_pressed_no_signal does not release the rest of a ButtonGroup.
	for s in _tabs:
		(_tabs[s] as Button).set_pressed_no_signal(s == slot)
	var is_weapon := String(slot).begins_with("weapon_") or slot == &"gloves" or slot == &"tracer"
	_weapon_row.visible = is_weapon
	for wid in _weapon_buttons:
		(_weapon_buttons[wid] as Button).set_pressed_no_signal(wid == _weapon_id)
	_update_weapon_rank()
	_build_grid()
	var current := _worn(slot)
	_select(current if current else (_cards[0].item if not _cards.is_empty() else null), false)
	_scroll.scroll_vertical = 0


## Switches the weapon that weapon cosmetics are previewed on and equipped to.
func select_weapon(weapon_id: StringName) -> void:
	_weapon_id = weapon_id
	show_category(_slot)


## Selects an item by id (opening its category).
func select_item(id: StringName) -> void:
	var it := Cosmetics.item(id)
	if it == null:
		return
	if it.slot != _slot:
		show_category(it.slot)
	_select(it, false)


func _ctx() -> StringName:
	return _weapon_id if String(_slot).begins_with("weapon_") else &""


## What is worn in a slot right now (equipped, or the slot's default).
func _worn(slot: StringName) -> CosmeticItem:
	return Cosmetics.equipped_or_default(slot, _weapon_id if String(slot).begins_with("weapon_") else &"")


func _build_grid() -> void:
	for c in _grid.get_children():
		c.queue_free()
	_cards.clear()
	for it in LockerCatalog.items(_slot, _weapon_id):
		var card := LockerCard.new(it, Cosmetics.is_owned(it, _ctx()), GameData.weapon(_weapon_id))
		card.pressed.connect(_select.bind(it, true))
		card.gui_input.connect(_on_card_input.bind(it))
		_grid.add_child(card)
		_cards.append(card)
		# Thumbnails bake only once the Locker has been opened.
		if _opened and card.wants_thumbnail():
			_thumbs.request(it, card.set_thumbnail, card.weapon)
	_update_states()


func _on_card_input(event: InputEvent, it: CosmeticItem) -> void:
	if event is InputEventMouseButton and event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
		_equip_item(it)


func _select(it: CosmeticItem, by_player: bool) -> void:
	_selected = it
	if it == null:
		return
	var was_new := Cosmetics.is_new(it)
	if was_new:
		Cosmetics.mark_seen(it)
	if by_player:
		Sfx.play(&"cos_equip_effect" if was_new else &"cos_select", -9.0 if was_new else -8.0)
	_update_states()
	_update_details()
	_update_preview(false)


func _update_states() -> void:
	var worn := _worn(_slot)
	for card in _cards:
		card.set_state(card.item == worn, card.item == _selected)
	for slot in _tab_badges:
		var n := Cosmetics.new_count(slot)
		var label: Label = _tab_badges[slot]
		label.text = str(n)
		label.get_parent().visible = n > 0
	var owned := 0
	for it in GameData.cosmetics():
		if Cosmetics.is_owned_anywhere(it):
			owned += 1
	_collection.text = "Collection  %d / %d" % [owned, GameData.cosmetics().size()]
	_collection_bar.value = float(owned) / maxf(1.0, GameData.cosmetics().size())


func _update_weapon_rank() -> void:
	var w := GameData.weapon(_weapon_id)
	if w == null:
		_weapon_rank.text = ""
		return
	_weapon_rank.text = "Mastery: %s" % UiKit.rank_name(Mastery.rank(w.id), w.max_rank()).capitalize()


func _update_details() -> void:
	var it := _selected
	var owned := Cosmetics.is_owned(it, _ctx())
	var rc := CosmeticItem.rarity_color(it.rarity)
	_name.text = it.display_name
	_rarity.text = CosmeticItem.rarity_name(it.rarity).to_upper()
	_rarity_pill.add_theme_stylebox_override("panel", UiKit.box(rc, Color.TRANSPARENT, 10, 0, 6))
	var where := ""
	if it.is_weapon_slot():
		var w := GameData.weapon(it.weapon_id)
		where = "  ·  %s only" % w.display_name if w else "  ·  fits every weapon"
	_category.text = LockerCatalog.category_label(it).to_upper() + where.to_upper()
	_description.text = it.description
	var p := LockerCatalog.progress(it)
	if owned:
		_unlock.text = "Unlocked" if it.requirement else "Yours from the start"
		_unlock.add_theme_color_override("font_color", UiKit.GREEN)
		_unlock_bar.visible = false
	else:
		var extra := LockerCatalog.progress_text(it)
		_unlock.text = "LOCKED  ·  %s%s" % [LockerCatalog.unlock_text(it), ("   (%s)" % extra) if extra != "" else ""]
		_unlock.add_theme_color_override("font_color", UiKit.AMBER)
		_unlock_bar.visible = p >= 0.0
		_unlock_bar.value = maxf(0.0, p)
	var worn := _worn(it.slot) == it
	_equip.disabled = not owned or worn
	_equip.text = "EQUIPPED" if worn else ("EQUIP" if owned else "LOCKED")
	var off := UiKit.box(Color("0d8f9a") if worn else Color(0.3, 0.27, 0.42), Color("0a5f68") if worn else Color(0.2, 0.17, 0.32), 22, 0, 16)
	off.border_width_bottom = 8
	_equip.add_theme_stylebox_override("disabled", off)
	_equip.add_theme_color_override("font_disabled_color", Color.WHITE if worn else Color(1, 1, 1, 0.45))
	_unequip.visible = worn and not LockerCatalog.has_default(it.slot) and Cosmetics.equipped(it.slot, _ctx()) == it


func _update_preview(flourish: bool) -> void:
	var it := _selected
	var weapon := GameData.weapon(_weapon_id)
	_operator_view.visible = it.slot == &"avatar"
	_card_view.visible = it.slot == &"banner" or it.slot == &"title"
	_stage.visible = not (_operator_view.visible or _card_view.visible)
	match it.slot:
		&"avatar":
			_operator_view.show_operator(it, flourish)
		&"banner", &"title":
			_card.preview(it.slot, it)
			_big_banner.visible = it.slot == &"banner"
			_big_banner.set_banner(it if it.slot == &"banner" else null)
			_big_title.visible = it.slot == &"title"
			_big_title.text = it.display_name.to_upper()
			_big_title.add_theme_color_override("font_color", CosmeticItem.rarity_color(it.rarity).lerp(Color.WHITE, 0.35))
		&"gloves":
			var arms := Cosmetics.weapon_loadout(_weapon_id)
			arms["arms"] = it
			_stage.show_arms(weapon, arms)
		&"kill_effect":
			_stage.show_kill_effect(it)
		&"tracer":
			_stage.show_tracer(it, weapon)
		_:
			var loadout := Cosmetics.weapon_loadout(_weapon_id)
			loadout[String(it.slot).trim_prefix("weapon_")] = it
			_stage.show_weapon(weapon, loadout)


func _equip_item(it: CosmeticItem) -> void:
	if it == null or not Cosmetics.is_owned(it, _ctx()):
		Sfx.play(&"deny", -6.0)
		return
	if Cosmetics.equip(it.slot, it, _ctx()):
		Sfx.play(LockerCatalog.category(it.slot)["sound"], -3.0)
		_selected = it
		_update_states()
		_update_details()
		_update_preview(true)


func _unequip_slot() -> void:
	Cosmetics.equip(_slot, null, _ctx())
	Sfx.play(&"cos_unequip", -6.0)
	_update_states()
	_update_details()
	_update_preview(false)
