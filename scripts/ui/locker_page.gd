class_name LockerPage
extends MenuPage
## The Locker: everything the player owns or could own, sorted into four
## groups (header tabs): CHARACTER (operators, gloves), WEAPON (skins, Prize
## Prints, sights, cells, charms, decals), EFFECTS (kill effects, tracers)
## and PROFILE (banners, titles). Under them, the group's categories and, for
## weapon items, which weapon is being customised: a PRIMARIES / SECONDARIES
## choice (keys 1 / 2), then the arrows step through that class's weapons
## (the page remembers the class and the weapon last picked in each). The
## tray shows the category's cards under a toolbar (search, SORT, SHOW, FROM,
## and FITS on the weapon tabs; kept per tab);
## beside it, the selected item large in the display case and a short
## signboard (name, rarity, where it comes from, its one action). The PRINTS
## tab lists the player's Prize Prints with the print inspect view beside.
##
## Keys: arrows browse (the case follows), Enter equips or buys, A / D (or
## the triggers) walk the categories across the groups. Mouse: click
## selects, double-click acts.

## Shown on the purchase stamp of the display case.
const BOUGHT_TEXT := "ADDED TO YOUR LOCKER"
const SIDE_WIDTH := 700.0
const CARD_GAP := 12
## Room around the cards for the hover growth and the focus ring.
const GRID_MARGIN := 14
## Browsing with the keyboard builds the 3D preview once the focus rests.
const PREVIEW_DELAY := 0.09
## The class choice beside the weapon picker, in Loadout slot order.
const CLASS_TABS := ["PRIMARIES", "SECONDARIES"]
const CLASS_TAB_WIDTH := 176.0
## Profile.section("menu") key: {"class": slot index, "primary": id, "secondary": id}.
const MEMORY_KEY := "locker_weapons"

var _slot: StringName = &"avatar"
var _weapon_id: StringName
var _selected: CosmeticItem
var _selected_print: Dictionary = {}
var _built := false
var _trigger_held := 0
## Tab id -> LockerFilters.State (what each tab was sorted and filtered by).
var _states := {}
var _header: HBoxContainer
var _groups: KitTabs
## The categories of the open group (one KitTabs per group, one shown).
var _tabs: KitTabs
var _group_tabs := {}
var _weapon_box: HBoxContainer
var _weapon_plate: SlotPlate
var _class_tabs: Array[SignButton] = []
var _collection: Label
var _collection_bar: ProgressBar
var _toolbar: LockerToolbar
var _caption: Label
var _caption_note: Label
var _scroll: ScrollContainer
var _grid: GridContainer
var _empty: VBoxContainer
var _empty_title: Label
var _empty_text: Label
var _empty_button: SignButton
var _cards: Array[LockerCard] = []
var _print_cards: Array[PrintCard] = []
var _card_group := ButtonGroup.new()
var _thumbs: CosmeticThumbs
var _item_side: VBoxContainer
var _showcase: CosmeticShowcase
var _panel: CosmeticPanel
var _inspect: PrintInspect
var _print_button: SignButton
var _preview_timer: Timer


func uses_shell_header() -> bool:
	return true


func header_extra() -> Control:
	return _header


func _ready() -> void:
	_weapon_id = _first_weapon()
	_thumbs = CosmeticThumbs.new()
	add_child(_thumbs)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	_preview_timer = Timer.new()
	_preview_timer.one_shot = true
	_preview_timer.wait_time = PREVIEW_DELAY
	_preview_timer.timeout.connect(_show_preview.bind(false))
	add_child(_preview_timer)
	_build_header()
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", UiKit.GAP_M)
	add_child(col)
	col.add_child(_build_strip())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", UiKit.GAP_L)
	col.add_child(body)
	body.add_child(_build_tray())
	body.add_child(_build_side())
	visibility_changed.connect(_on_visibility_changed)
	Wallet.balance_changed.connect(_on_balance_changed)


## Makes the first category's cards ahead of the first visit, a few per
## frame (they stay hidden until refresh() fills them).
func prewarm(queue: BuildQueue) -> void:
	var count := LockerFilters.items(_slot, _weapon_id, _state(_slot)).size()
	for i in range(0, count, 3):
		queue.add(_prewarm_cards.bind(mini(i + 3, count)))


func _prewarm_cards(count: int) -> void:
	while _cards.size() < count:
		var card := _new_card()
		card.visible = false
		_cards.append(card)


func refresh() -> void:
	_built = true
	_refresh_collection()
	_refresh_badges()
	_open(_slot, _selected)
	_deal_cards()


func first_focus() -> Control:
	if _slot == LockerFilters.PRINTS:
		return _print_card_of(_selected_print) if _print_card_of(_selected_print) else _toolbar.search_box()
	var card := _card_of(_selected)
	return card if card else _toolbar.search_box()


func handle_back() -> bool:
	# Esc in the search box leaves the box first.
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit and is_ancestor_of(focus):
		_focus_selected()
		return true
	return false


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or KitDialog.open_count > 0:
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	if _weapon_box.is_visible_in_tree() and (event.is_action_pressed("weapon_1") or event.is_action_pressed("weapon_2")):
		_pick_class(Loadout.PRIMARY if event.is_action_pressed("weapon_1") else Loadout.SECONDARY)
		get_viewport().set_input_as_handled()
		return
	var step := 0
	if event.is_action_pressed("move_left"):
		step = -1
	elif event.is_action_pressed("move_right"):
		step = 1
	elif event is InputEventJoypadMotion:
		step = _trigger_step(event as InputEventJoypadMotion)
	if step != 0:
		_step_tab(step)
		get_viewport().set_input_as_handled()


## -1 / 1 once per pull of the left / right trigger.
func _trigger_step(event: InputEventJoypadMotion) -> int:
	var side := 0
	if event.axis == JOY_AXIS_TRIGGER_LEFT:
		side = -1
	elif event.axis == JOY_AXIS_TRIGGER_RIGHT:
		side = 1
	if side == 0:
		return 0
	if event.axis_value < 0.3 and _trigger_held == side:
		_trigger_held = 0
	elif event.axis_value > 0.6 and _trigger_held != side:
		_trigger_held = side
		return side
	return 0


# --- layout ---------------------------------------------------------------------

## Right of the marquee: the four groups, and the collection.
func _build_header() -> void:
	_header = HBoxContainer.new()
	_header.add_theme_constant_override("separation", UiKit.GAP_L)
	_groups = UiKit.tabs(28)
	_groups.name = "LockerTabs"
	_groups.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for g in LockerFilters.GROUPS:
		var b := _groups.add_tab(g["id"], String(g["label"]))
		b.tooltip_text = ", ".join((g["slots"] as Array).map(func(s): return LockerFilters.tab_label(s).capitalize()))
	_groups.tab_changed.connect(_on_group_changed)
	_header.add_child(_groups)
	_header.add_child(UiKit.filler())
	var progress := VBoxContainer.new()
	progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress.add_theme_constant_override("separation", UiKit.GAP_XS)
	_header.add_child(progress)
	_collection = UiKit.label("", UiKit.SIZE_SMALL, UiKit.CREAM, true)
	progress.add_child(_collection)
	_collection_bar = UiKit.progress(0.0, 10.0, UiKit.AMBER)
	_collection_bar.custom_minimum_size.x = 200
	progress.add_child(_collection_bar)


## The open group's categories on a dark strip, and the weapon being customised.
func _build_strip() -> Control:
	var strip := UiKit.card_panel(6)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiKit.GAP_M)
	strip.add_child(row)
	var slots := {}
	for it in GameData.cosmetics():
		slots[it.slot] = true
	for g in LockerFilters.GROUPS:
		var tabs := KitTabs.make(24, true)
		tabs.add_theme_constant_override("separation", UiKit.GAP_XS)
		tabs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for slot in g["slots"]:
			# A category the game has no items for (yet) gets no tab.
			if slot != LockerFilters.PRINTS and not slots.has(slot):
				continue
			var tab := tabs.add_tab(slot, LockerFilters.tab_label(slot))
			tab.custom_minimum_size.x = 150
			tab.tooltip_text = "Your Prize Prints: one-of-a-kind skins" if slot == LockerFilters.PRINTS else String(LockerCatalog.category(slot)["label"])
		tabs.tab_changed.connect(_on_tab_changed)
		tabs.visible = false
		row.add_child(tabs)
		_group_tabs[g["id"]] = tabs
	_tabs = _group_tabs[LockerFilters.GROUPS[0]["id"]]
	_tabs.visible = true
	row.add_child(UiKit.filler())
	_weapon_box = HBoxContainer.new()
	_weapon_box.add_theme_constant_override("separation", UiKit.GAP_S)
	row.add_child(_weapon_box)
	_weapon_box.add_child(_build_class_tabs())
	var previous := UiKit.icon_button(&"icon_arrow_left", "Previous weapon")
	previous.pressed.connect(_step_weapon.bind(-1))
	_weapon_box.add_child(previous)
	_weapon_plate = UiKit.slot_plate("CUSTOMISING", "")
	_weapon_plate.custom_minimum_size.x = 380
	_weapon_box.add_child(_weapon_plate)
	var next := UiKit.icon_button(&"icon_arrow_right", "Next weapon")
	next.pressed.connect(_step_weapon.bind(1))
	_weapon_box.add_child(next)
	return strip


## PRIMARIES over SECONDARIES: the class the weapon picker steps through.
## Compact tabs, so the two stack in the height of the weapon plate.
func _build_class_tabs() -> Control:
	var col := VBoxContainer.new()
	col.name = "WeaponClass"
	col.add_theme_constant_override("separation", UiKit.GAP_XS)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var group := ButtonGroup.new()
	for slot_index in 2:
		var tab := SignButton.make_tab(CLASS_TABS[slot_index], group, 22)
		tab.name = "Class%s" % String(Loadout.SLOT_NAMES[slot_index])
		tab.custom_minimum_size.x = CLASS_TAB_WIDTH
		tab.tooltip_text = "Customise a %s weapon [%d]" % [String(Loadout.SLOT_NAMES[slot_index]).to_lower(), slot_index + 1]
		for state in [&"normal", &"hover", &"pressed", &"hover_pressed"]:
			var box := tab.get_theme_stylebox(state).duplicate() as StyleBox
			box.content_margin_top = 4
			box.content_margin_bottom = 8
			box.content_margin_left = 14
			box.content_margin_right = 14
			tab.add_theme_stylebox_override(state, box)
		tab.pressed.connect(_on_class_tab.bind(slot_index))
		col.add_child(tab)
		_class_tabs.append(tab)
	return col


## The tray: the toolbar, a caption with what is owned here, and the cards.
func _build_tray() -> Control:
	var tray := UiKit.metal_frame(28)
	tray.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiKit.GAP_S)
	tray.add_child(col)
	_toolbar = LockerToolbar.new()
	_toolbar.changed.connect(_on_filters_changed)
	col.add_child(_toolbar)
	var caption := UiKit.section("", " ")
	_caption = caption.get_child(0) as Label
	_caption_note = caption.get_child(2) as Label
	col.add_child(caption)
	var area := Control.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(area)
	_scroll = UiKit.scroll()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.resized.connect(_fit_columns)
	# The tray follows focus itself (see _on_focus_changed): the scroll
	# container's own follow would chase cards that are still popping in.
	_scroll.follow_focus = false
	area.add_child(_scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "top", "right", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, GRID_MARGIN)
	_scroll.add_child(pad)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", CARD_GAP)
	_grid.add_theme_constant_override("v_separation", CARD_GAP)
	pad.add_child(_grid)
	area.add_child(_build_empty())
	return tray


## What the tray says when it has no cards: why, and the one thing to do.
func _build_empty() -> Control:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_empty = VBoxContainer.new()
	_empty.alignment = BoxContainer.ALIGNMENT_CENTER
	_empty.add_theme_constant_override("separation", UiKit.GAP_M)
	center.add_child(_empty)
	_empty_title = UiKit.sign_label("", UiKit.SIZE_HEADING)
	_empty_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.add_child(_empty_title)
	_empty_text = UiKit.body("", 560, UiKit.SIZE_BODY, UiKit.MUTED)
	_empty_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.add_child(_empty_text)
	_empty_button = UiKit.sign_button("", SignButton.Kind.SECONDARY, 28)
	_empty_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_empty_button.pressed.connect(_on_empty_action)
	_empty.add_child(_empty_button)
	center.visible = false
	return center


## The display case over the item's signboard, or the print inspect view.
func _build_side() -> Control:
	var side := Control.new()
	side.custom_minimum_size.x = SIDE_WIDTH
	_item_side = VBoxContainer.new()
	_item_side.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_item_side.add_theme_constant_override("separation", UiKit.GAP_M)
	side.add_child(_item_side)
	_showcase = CosmeticShowcase.new()
	_showcase.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_item_side.add_child(_showcase)
	_panel = CosmeticPanel.new()
	_panel.custom_minimum_size.y = 292
	_panel.equip_requested.connect(_equip)
	_panel.unequip_requested.connect(_unequip)
	_panel.buy_requested.connect(_buy)
	_item_side.add_child(_panel)
	_print_button = UiKit.sign_button("", SignButton.Kind.SECONDARY, 22)
	_print_button.visible = false
	_print_button.pressed.connect(_open_prints_of_selected)
	_showcase.add_child(_print_button)
	_print_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_print_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_print_button.position += Vector2(-22.0, 20.0)
	_inspect = PrintInspect.new()
	_inspect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_inspect.visible = false
	_inspect.changed.connect(_on_print_changed)
	side.add_child(_inspect)
	return side


## As many columns as fit the tray (it is wider on an ultrawide screen).
func _fit_columns() -> void:
	var room := _scroll.size.x - GRID_MARGIN * 2.0 - 18.0
	_grid.columns = clampi(int((room + CARD_GAP) / (LockerCard.CARD_SIZE.x + CARD_GAP)), 2, 9)


# --- opening tabs ------------------------------------------------------------------

## Opens a category tab (by slot, or LockerFilters.PRINTS) and selects what is worn there.
func show_category(slot: StringName) -> void:
	_open(slot, null)


## Shows only `id` of the tray's "show" choices: all, owned, locked or sale.
func set_show_filter(id: StringName) -> void:
	var s := _state(_slot)
	s.show = ({&"owned": LockerFilters.Show.OWNED, &"locked": LockerFilters.Show.LOCKED, &"sale": LockerFilters.Show.FOR_SALE} as Dictionary).get(id, LockerFilters.Show.ALL)
	_toolbar.set_state(s, _slot == LockerFilters.PRINTS, _weapon_class())
	_on_filters_changed()


## Opens a category and selects `prefer` if it is there, else its first item.
func _open(slot: StringName, prefer: CosmeticItem) -> void:
	_slot = slot
	var group: Dictionary = LockerFilters.group_of(slot)
	_groups.select(group["id"])
	for id in _group_tabs:
		(_group_tabs[id] as KitTabs).visible = id == group["id"]
	_tabs = _group_tabs[group["id"]]
	_tabs.select(slot)
	var prints := slot == LockerFilters.PRINTS
	_weapon_box.visible = prints or LockerCatalog.uses_weapon(slot)
	_item_side.visible = not prints
	_inspect.visible = prints
	_toolbar.set_state(_state(slot), prints, _weapon_class())
	_refresh_weapon_plate()
	if not _built:
		return
	_scroll.scroll_vertical = 0
	if prints:
		_fill_prints()
		_select_print(_print_cards[0].print_data if not _print_cards.is_empty() and _print_cards[0].visible else {}, false)
		return
	_fill_grid()
	if _card_of(prefer):
		_select(prefer, false)
	else:
		_select(_cards[0].item if _cards[0].visible else null, false)


## Switches the weapon that weapon cosmetics are previewed on and equipped to.
func select_weapon(weapon_id: StringName) -> void:
	if GameData.weapon(weapon_id) == null:
		return
	_set_weapon(weapon_id)
	show_category(_slot)


## Selects an item by id (opening its category and, for an item made for one
## weapon, that weapon). Filters that would hide it are cleared.
func select_item(id: StringName) -> void:
	var it := Cosmetics.item(id)
	if it == null:
		return
	if it.is_weapon_slot() and it.weapon_id != &"":
		_set_weapon(it.weapon_id)
	var s := _state(it.slot)
	if not LockerFilters.items(it.slot, _weapon_id, s).has(it):
		s.clear()
	_open(it.slot, it)
	if is_visible_in_tree():
		_focus_selected()
	_reveal_selected()


## A tab's filter state (made on first use).
func _state(slot: StringName) -> LockerFilters.State:
	if not _states.has(slot):
		_states[slot] = LockerFilters.State.new()
	return _states[slot]


func _ctx() -> StringName:
	return LockerCatalog.context(_slot, _weapon_id)


func _weapon() -> WeaponData:
	return GameData.weapon(_weapon_id)


## "PRIMARY" or "SECONDARY" while the open tab is customised per weapon (the
## toolbar's FITS texts), else "".
func _weapon_class() -> String:
	var per_weapon := LockerCatalog.is_weapon_slot(_slot) or _slot == LockerFilters.PRINTS
	return LockerFilters.weapon_class_of(_weapon()) if per_weapon and _weapon() else ""


func _step_tab(direction: int) -> void:
	var order := LockerFilters.all_tabs().filter(func(s): return _has_tab(s))
	var at := order.find(_slot)
	UiSound.tab()
	_switch_to(order[posmod(at + direction, order.size())], false)


func _has_tab(slot: StringName) -> bool:
	for id in _group_tabs:
		if (_group_tabs[id] as KitTabs).button(slot):
			return true
	return false


## Opens `slot` from a tab or a key; `keep_tab_focus` leaves the focus on the tab rows.
func _switch_to(slot: StringName, keep_tab_focus: bool) -> void:
	show_category(slot)
	_deal_cards()
	if not keep_tab_focus:
		_focus_selected()


# --- the cards ---------------------------------------------------------------------

## Shows the items of the open category on the cards (cards are reused).
func _fill_grid() -> void:
	var items := LockerFilters.items(_slot, _weapon_id, _state(_slot))
	if _cards.size() < items.size() or _cards.is_empty():
		for i in maxi(1, items.size()) - _cards.size():
			_cards.append(_new_card())
	var weapon := _weapon()
	for card in _print_cards:
		card.visible = false
	for i in _cards.size():
		var card := _cards[i]
		card.visible = i < items.size()
		if card.visible:
			card.show_item(items[i], weapon, _thumbs)
	_refresh_caption()
	_show_empty(items.is_empty())


func _fill_prints() -> void:
	var list := LockerFilters.prints(_weapon_id, _state(LockerFilters.PRINTS))
	while _print_cards.size() < list.size():
		var card := PrintCard.create(LockerCard.CARD_SIZE + Vector2(0, 6))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.button_group = _card_group
		card.pressed.connect(_on_print_pressed.bind(card))
		card.focus_entered.connect(_on_print_pressed.bind(card))
		card.gui_input.connect(_on_print_input.bind(card))
		_grid.add_child(card)
		_print_cards.append(card)
	for card in _cards:
		card.visible = false
	var weapon := _weapon()
	for i in _print_cards.size():
		var card := _print_cards[i]
		card.visible = i < list.size()
		if card.visible:
			card.show_print(list[i], weapon, _thumbs)
	_refresh_caption()
	_show_empty(list.is_empty())


func _new_card() -> LockerCard:
	var card := LockerCard.create()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.button_group = _card_group
	card.pressed.connect(_on_card_pressed.bind(card))
	card.focus_entered.connect(_on_card_focused.bind(card))
	card.gui_input.connect(_on_card_input.bind(card))
	_grid.add_child(card)
	return card


func _card_of(it: CosmeticItem) -> LockerCard:
	if it == null:
		return null
	for card in _cards:
		if card.visible and card.item == it:
			return card
	return null


func _print_card_of(p: Dictionary) -> PrintCard:
	if p.is_empty():
		return null
	for card in _print_cards:
		if card.visible and card.print_data == p:
			return card
	return null


## Why the tray is empty, and the one way out.
func _show_empty(empty: bool) -> void:
	var holder := _empty.get_parent() as Control
	holder.visible = empty
	if not empty:
		return
	var s := _state(_slot)
	var prints := _slot == LockerFilters.PRINTS
	var noun := "prints" if prints else String(LockerCatalog.category(_slot)["label"]).to_lower()
	if s.narrows():
		_empty_title.text = "NOTHING MATCHES"
		_empty_text.text = "No %s match these filters%s." % [noun, " or this search" if s.search.strip_edges() != "" else ""]
		_empty_button.text = "CLEAR FILTERS"
	elif prints:
		_empty_title.text = "NO PRIZE PRINTS YET"
		_empty_text.text = "Every run can earn Prize Capsules. Open them on the Prizes page: each print is a one-of-a-kind skin with its own serial."
		_empty_button.text = "GO TO PRIZES"
	else:
		_empty_title.text = "NOTHING HERE YET"
		_empty_text.text = "There are no %s to show." % noun
		_empty_button.text = "SHOW ALL"
	_empty_button.visible = s.narrows() or prints


func _on_empty_action() -> void:
	var s := _state(_slot)
	if s.narrows():
		s.clear()
		_toolbar.set_state(s, _slot == LockerFilters.PRINTS, _weapon_class())
		_on_filters_changed()
		_focus_selected()
	elif _slot == LockerFilters.PRINTS:
		open_page.emit(&"prizes")


func _on_filters_changed() -> void:
	if not _built:
		return
	_scroll.scroll_vertical = 0
	if _slot == LockerFilters.PRINTS:
		var keep := _selected_print
		_fill_prints()
		_select_print(keep if _print_card_of(keep) else (_print_cards[0].print_data if not _print_cards.is_empty() and _print_cards[0].visible else {}), false)
	else:
		var keep := _selected
		_fill_grid()
		_select(keep if _card_of(keep) else (_cards[0].item if _cards[0].visible else null), false)
	_deal_cards()


func _on_card_pressed(card: LockerCard) -> void:
	if card.item != _selected:
		_select(card.item, true)


## Keyboard and gamepad: the case follows the focus.
func _on_card_focused(card: LockerCard) -> void:
	if card.item != _selected:
		_select(card.item, true)


## Enter (or the gamepad's accept) and a double-click act on the item.
func _on_card_input(event: InputEvent, card: LockerCard) -> void:
	if not _is_activation(event):
		return
	card.accept_event()
	if card.item != _selected:
		_select(card.item, true)
	_activate(card.item)


func _is_activation(event: InputEvent) -> bool:
	var click := event as InputEventMouseButton
	var double_click := click != null and click.double_click and click.button_index == MOUSE_BUTTON_LEFT
	return double_click or event.is_action_pressed("ui_accept")


func _select(it: CosmeticItem, by_player: bool) -> void:
	_selected = it
	_panel.show_item(it, _weapon_id)
	_showcase.visible = it != null
	_refresh_print_button()
	var card := _card_of(it)
	if card == null:
		return
	card.selected = true
	if Cosmetics.is_new(it):
		Cosmetics.mark_seen(it)
		card.set_new(false)
		_refresh_badges()
	if by_player:
		_preview_timer.start()
	else:
		_preview_timer.stop()
		_show_preview(false)


func _show_preview(flourish: bool) -> void:
	if _selected and _slot != LockerFilters.PRINTS:
		_showcase.show_item(_selected, _weapon(), flourish)


## The item's one action: equip it, buy it, or say why not.
func _activate(it: CosmeticItem) -> void:
	match LockerCatalog.state(it, _weapon_id):
		LockerCatalog.State.OWNED:
			_equip(it)
		LockerCatalog.State.FOR_SALE:
			_buy(it)
		LockerCatalog.State.LOCKED:
			_panel.refused()


func _equip(it: CosmeticItem) -> void:
	if it == null or not Cosmetics.equip(it.slot, it, _ctx()):
		_panel.refused()
		return
	Sfx.play(LockerCatalog.category(it.slot)["sound"], -3.0)
	_after_change(true)


func _unequip(it: CosmeticItem) -> void:
	Cosmetics.equip(it.slot, null, _ctx())
	Sfx.play(&"cos_unequip", -6.0)
	_after_change(false)
	_focus_selected()


func _buy(it: CosmeticItem) -> void:
	var dialog := PurchaseFlow.request(self, it, _ctx(), _on_bought)
	if dialog:
		dialog.cancelled.connect(_focus_selected)


## The purchase moment: the case celebrates, and EQUIP is one press away.
func _on_bought(it: CosmeticItem) -> void:
	Cosmetics.mark_seen(it)
	_refresh_states()
	_panel.refresh()
	_refresh_collection()
	_refresh_caption()
	if it == _selected:
		_showcase.celebrate(BOUGHT_TEXT)
	var action := _panel.action_button()
	if action:
		action.grab_focus.call_deferred()
		_panel.pulse_action.call_deferred()


## Cards, the signboard and the case after equipping or unequipping.
func _after_change(flourish: bool) -> void:
	_refresh_states()
	_panel.refresh()
	_preview_timer.stop()
	_show_preview(flourish)


# --- prints ---------------------------------------------------------------------------

func _on_print_pressed(card: PrintCard) -> void:
	if card.print_data != _selected_print:
		_select_print(card.print_data, true)


## Enter or a double-click wears the print on the weapon being customised
## (or takes it off when it is already worn there).
func _on_print_input(event: InputEvent, card: PrintCard) -> void:
	if not _is_activation(event):
		return
	card.accept_event()
	if card.print_data != _selected_print:
		_select_print(card.print_data, true)
	var p := card.print_data
	if PrizePrints.equipped(_weapon_id) == p:
		PrizePrints.take_off(_weapon_id)
		Sfx.play(&"cos_unequip", -6.0)
	elif PrizePrints.equip(p, _weapon_id):
		UiSound.equip()
	else:
		UiSound.deny()
		UiKit.toast("This print fits only its own weapon", UiKit.AMBER)
		return
	_on_print_changed()


func _select_print(p: Dictionary, _by_player: bool) -> void:
	_selected_print = p
	_inspect.show_print(p, _weapon_id)
	var card := _print_card_of(p)
	if card == null:
		return
	card.selected = true
	if bool(p.get("new", false)):
		PrizePrints.mark_seen(p)
		card.refresh_state()
		_refresh_badges()


## Worn, kept or recycled in the inspect view: the cards follow.
func _on_print_changed() -> void:
	if _print_card_of(_selected_print) == null or not PrizePrints.held().has(_selected_print):
		_on_filters_changed()
		return
	for card in _print_cards:
		if card.visible:
			card.refresh_state()
	_inspect.show_print(_selected_print, _weapon_id)


## The showcase's "YOUR PRINTS" button: the Prints tab, searched to this finish.
func _open_prints_of_selected() -> void:
	if _selected == null:
		return
	var s := _state(LockerFilters.PRINTS)
	s.clear()
	s.search = _selected.display_name
	_switch_to(LockerFilters.PRINTS, false)


func _refresh_print_button() -> void:
	var count := PrizePrints.prints_of(_selected.id).size() if _selected and _selected.slot == &"weapon_finish" else 0
	_print_button.visible = count > 0
	if count == 0:
		return
	var worn := PrizePrints.equipped(_weapon_id)
	var wearing := not worn.is_empty() and StringName(String(worn["f"])) == _selected.id
	_print_button.text = ("WEARING PRINT %s" % PrintLook.serial_text(int(worn["serial"]))) if wearing else "YOUR PRINTS  x%d" % count


# --- small refreshes ----------------------------------------------------------------

## The cards on show pop in one after another.
func _deal_cards() -> void:
	var shown: Array = _cards.filter(func(card: LockerCard) -> bool: return card.visible)
	shown.append_array(_print_cards.filter(func(card: PrintCard) -> bool: return card.visible))
	UiFx.stagger_in(shown)


## Scrolls the tray to the selected card once the grid has been laid out.
func _reveal_selected() -> void:
	await get_tree().process_frame
	var card := _card_of(_selected)
	if card:
		_scroll_to(card)


## Keeps the focused card in view as keyboard or gamepad focus moves.
func _on_focus_changed(control: Control) -> void:
	if control == null or not _built or not _grid.is_ancestor_of(control):
		return
	while control.get_parent() != _grid:
		control = control.get_parent() as Control
	_scroll_to(control)


## Scrolls the tray just enough to show `card`, from its place in the grid
## rather than its on-screen rect: cards still popping in (or lifted) would
## scroll the tray past the top row and clip its corner tags. The grid's
## margin stays in view.
func _scroll_to(card: Control) -> void:
	# Focus can land before the tray is laid out (no height yet), when any
	# scroll would overshoot to the bottom: wait a frame for the layout.
	if _scroll.size.y <= 1.0:
		await get_tree().process_frame
		if not is_instance_valid(card) or _scroll.size.y <= 1.0:
			return
	var top := card.position.y
	var bottom := card.position.y + card.size.y + GRID_MARGIN * 2.0
	if top < _scroll.scroll_vertical:
		_scroll.scroll_vertical = int(top)
	elif bottom > _scroll.scroll_vertical + _scroll.size.y:
		_scroll.scroll_vertical = int(ceilf(bottom - _scroll.size.y))


func _focus_selected() -> void:
	var target := first_focus()
	if target:
		target.grab_focus()


func _refresh_states() -> void:
	for card in _cards:
		if card.visible:
			card.refresh_state()


func _refresh_badges() -> void:
	var group_counts := {}
	for id in _group_tabs:
		var tabs: KitTabs = _group_tabs[id]
		var total := 0
		for slot in tabs.ids():
			var count := PrizePrints.new_count() if slot == LockerFilters.PRINTS else Cosmetics.new_count(slot)
			total += count
			tabs.set_badge(slot, count)
			_tuck_badge(tabs.button(slot))
		group_counts[id] = total
	for id in group_counts:
		_groups.set_badge(id, group_counts[id])


## Keeps a tab's count inside its top right corner.
static func _tuck_badge(tab: Control) -> void:
	var badge := tab.get_node_or_null("Badge") as Control if tab else null
	if badge:
		badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		badge.position += Vector2(-6.0, 2.0)


func _refresh_collection() -> void:
	var have := LockerCatalog.collection()
	_collection.text = "COLLECTION  %d / %d" % [have.x, have.y]
	_collection_bar.value = float(have.x) / maxf(1.0, have.y)


## "PRIMARY  ·  ION CARBINE  ·  WEAPON SKINS" and how many of the cards on show are owned.
func _refresh_caption() -> void:
	var weapon := _weapon()
	if _slot == LockerFilters.PRINTS:
		_caption.text = "YOUR PRIZE PRINTS"
		var shown := _print_cards.filter(func(c: PrintCard) -> bool: return c.visible).size()
		_caption_note.text = "%d of %d prints  ·  Enter wears one on the %s" % [shown, PrizePrints.held().size(), weapon.display_name if weapon else "weapon"]
		return
	var label := String(LockerCatalog.category(_slot)["label"]).to_upper()
	_caption.text = "%s  ·  %s  ·  %s" % [LockerFilters.weapon_class_of(weapon), weapon.display_name.to_upper(), label] if LockerCatalog.is_weapon_slot(_slot) and weapon else label
	var owned := 0
	var shown := 0
	for card in _cards:
		if card.visible:
			shown += 1
			if card.state <= LockerCatalog.State.OWNED:
				owned += 1
	var total := LockerCatalog.items(_slot, _weapon_id).size()
	_caption_note.text = "%d of %d owned" % [owned, shown] + ("  ·  showing %d of %d" % [shown, total] if shown < total else "")


func _refresh_weapon_plate() -> void:
	var weapon := _weapon()
	if weapon == null:
		return
	var per_weapon := LockerCatalog.is_weapon_slot(_slot) or _slot == LockerFilters.PRINTS
	_weapon_plate.set_caption("CUSTOMISING" if per_weapon else "SHOWN ON")
	_weapon_plate.active = per_weapon
	_weapon_plate.set_value(weapon.display_name.to_upper())
	_weapon_plate.set_note(Mastery.rank_label(Mastery.rank(weapon.id)).capitalize())
	var slot_index := Loadout.slot_for(weapon)
	for i in _class_tabs.size():
		_class_tabs[i].set_pressed_no_signal(i == slot_index)


# --- the weapon picker ---------------------------------------------------------------

## The weapon the page opens on: the one last customised in the class picked
## last, else the weapon played last.
func _first_weapon() -> StringName:
	var memory := _memory()
	var slot_index := clampi(int(memory.get("class", -1)), -1, 1)
	var id := StringName(String(memory.get(Loadout.SLOT_KEYS[slot_index], ""))) if slot_index >= 0 else &""
	if GameData.weapon(id) == null:
		id = StringName(String(Profile.data.get("last_weapon", "")))
	return id if GameData.weapon(id) else GameData.default_weapon_id()


func _memory() -> Dictionary:
	var menu := Profile.section("menu")
	if typeof(menu.get(MEMORY_KEY)) != TYPE_DICTIONARY:
		menu[MEMORY_KEY] = {}
	return menu[MEMORY_KEY]


## Customises `weapon_id` from now on and remembers it as its class's pick
## (saved with the profile when the page closes).
func _set_weapon(weapon_id: StringName) -> void:
	_weapon_id = weapon_id
	var slot_index := Loadout.slot_for(_weapon())
	var memory := _memory()
	memory["class"] = slot_index
	memory[Loadout.SLOT_KEYS[slot_index]] = String(weapon_id)


## The previous or next weapon of the class being customised.
func _step_weapon(direction: int) -> void:
	var weapons := Loadout.weapons_for(Loadout.slot_for(_weapon()))
	if weapons.is_empty():
		return
	var at := weapons.find(_weapon())
	UiSound.select()
	_switch_weapon(weapons[posmod(at + direction, weapons.size())].id)


func _on_class_tab(slot_index: int) -> void:
	UiSound.tab()
	_pick_class(slot_index)


## Switches the picker to a class: the weapon last customised there, else
## the one in that loadout slot.
func _pick_class(slot_index: int) -> void:
	var id := StringName(String(_memory().get(Loadout.SLOT_KEYS[slot_index], "")))
	var w := GameData.weapon(id)
	if w == null or Loadout.slot_for(w) != slot_index:
		id = Loadout.slot(slot_index)
	if Loadout.slot_for(_weapon()) == slot_index or GameData.weapon(id) == null:
		_refresh_weapon_plate()
		return
	_switch_weapon(id)


## Customises `weapon_id`; focus on the cards moves to the selected one.
func _switch_weapon(weapon_id: StringName) -> void:
	var focus := get_viewport().gui_get_focus_owner()
	var on_cards := focus != null and _grid.is_ancestor_of(focus)
	select_weapon(weapon_id)
	_deal_cards()
	if on_cards:
		_focus_selected()


func _on_group_changed(id: StringName) -> void:
	var tabs: KitTabs = _group_tabs[id]
	if not tabs.ids().is_empty():
		_switch_to(tabs.ids()[0], true)


func _on_tab_changed(slot: StringName) -> void:
	# A click or Enter on a tab keeps the focus on the tab row.
	var focus := get_viewport().gui_get_focus_owner()
	_switch_to(slot, focus != null and _tabs.is_ancestor_of(focus))


## Prices turn red or gold as the balance changes.
func _on_balance_changed(_balance: int) -> void:
	if _built and is_visible_in_tree() and _slot != LockerFilters.PRINTS:
		_refresh_states()
		_panel.refresh()


## Leaving the page saves which items have been looked at.
func _on_visibility_changed() -> void:
	if not is_visible_in_tree() and _built:
		Profile.save_profile()
